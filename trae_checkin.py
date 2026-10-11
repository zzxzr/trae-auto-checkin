#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Trae CN 自动签到工具 (Python 版)
改写自 TraeCheckin.ps1 / checkin.exe

依赖: pycryptodome  (pip install pycryptodome)
"""

import os
import sys
import json
import base64
import hashlib
import argparse
import urllib.request
import urllib.error
from datetime import datetime, timezone

try:
    from Crypto.Cipher import AES
except ImportError:
    print("缺少依赖 pycryptodome，请运行: pip install pycryptodome")
    sys.exit(1)

CANDIDATE_APPS = ['Trae CN', 'TRAE SOLO CN']

XOR_DATA = bytes([
    77, 212, 194, 230, 184, 49, 98, 9, 14, 82, 179, 199, 166, 115, 59, 164,
    28, 178, 70, 43, 130, 154, 181, 138, 25, 107, 57, 219, 87, 23, 117, 36,
    244, 155, 175, 127, 8, 232, 214, 141, 38, 167, 46, 55, 193, 169, 90, 47,
    31, 5, 165, 24, 146, 174, 242, 148, 151, 50, 182, 42, 56, 170, 221, 88,
])

USER_AGENT = (
    'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/50.0.2661.87 Safari/537.36'
)


def get_device_id(app_name):
    """从 tt_net_config.config 读取 device_id"""
    candidates = [
        os.path.join(os.environ.get('APPDATA', ''), app_name, 'ahanet', 'tt_net_config.config'),
        os.path.join(os.environ.get('ProgramData', ''), app_name, 'ahanet', 'tt_net_config.config'),
    ]
    config_path = next((p for p in candidates if os.path.isfile(p)), None)
    if not config_path:
        raise FileNotFoundError("未找到配置文件，尝试过:\n" + "\n".join(candidates))

    with open(config_path, 'rb') as f:
        config = f.read().decode('ascii', errors='replace')

    marker = 'device_id&#*'
    start = config.find(marker)
    if start < 0:
        raise ValueError(f"配置文件中未找到标记 {marker}")
    start += len(marker)
    end = config.find('@', start)
    if end < 0:
        end = len(config)
    device_id = config[start:end].strip()
    if not device_id:
        raise ValueError("device_id 为空")
    return device_id


def convert_from_trae_auth_info(base64_text):
    """iCubeAuthInfo(base64) -> AES-128-CBC -> JSON 文本"""
    t = base64.b64decode(base64_text)
    if len(t) < 38:
        raise ValueError("iCubeAuthInfo 数据长度不足 38")

    # key = t[6:38]  (32 字节)
    key = t[6:38]
    # shaKey = SHA512(key); h = SHA512(shaKey || XOR_DATA)
    sha_key = hashlib.sha512(key).digest()
    h = hashlib.sha512(sha_key + XOR_DATA).digest()
    # aesKey = h[0:16], iv = h[16:32]
    aes_key = h[0:16]
    iv = h[16:32]
    # 密文 = t[38:]
    cipher = t[38:]

    # AES-128-CBC 解密 (PaddingMode.None)
    plain = AES.new(aes_key, AES.MODE_CBC, iv).decrypt(cipher)
    if not plain:
        raise ValueError("AES 解密结果为空")

    # 手动 PKCS7 去填充
    pad = plain[-1]
    if 1 <= pad <= 16 and pad <= len(plain):
        plain = plain[:-pad]

    # 跳过前 64 字节，剩余为 UTF-8 JSON
    if len(plain) <= 64:
        raise ValueError("解密后数据过短，不是有效 JSON")
    return plain[64:].decode('utf-8')


def get_token(app_name):
    """从 storage.json 读取并解密 token"""
    storage_path = os.path.join(
        os.environ.get('APPDATA', ''), app_name, 'User', 'globalStorage', 'storage.json'
    )
    if not os.path.isfile(storage_path):
        raise FileNotFoundError(f"未找到 storage.json:\n{storage_path}")

    with open(storage_path, 'r', encoding='utf-8') as f:
        storage = json.load(f)

    i_cube_auth_info = storage.get('iCubeAuthInfo://icube.cloudide')
    if not i_cube_auth_info:
        raise ValueError("storage.json 中未找到 iCubeAuthInfo://icube.cloudide")

    json_text = convert_from_trae_auth_info(i_cube_auth_info)
    if not json_text:
        raise ValueError("iCubeAuthInfo 解密失败")

    token = json.loads(json_text).get('token')
    if not token:
        raise ValueError("JSON 中未找到 token")
    return token


def get_token_expiry(token):
    """解析 JWT token，返回剩余有效时间描述"""
    parts = token.split('.')
    if len(parts) != 3:
        return ''
    # base64url -> base64
    payload = parts[1].replace('-', '+').replace('_', '/')
    payload += '=' * (-len(payload) % 4)
    try:
        raw = base64.b64decode(payload)
        exp = json.loads(raw.decode('utf-8')).get('exp')
    except Exception:
        return ''
    if exp is None:
        return ''
    now = int(datetime.now(timezone.utc).timestamp())
    remain = exp - now
    if remain <= 0:
        return '已过期'
    days = remain // 86400
    hours = (remain % 86400) // 3600
    return f"剩余 {days} 天 {hours} 小时"


def invoke_trae_api(url, token, device_id, body):
    """发送 Trae API POST 请求并返回解析后的 JSON"""
    headers = {
        'Authorization': f'Cloud-IDE-JWT {token}',
        'x-device-id': device_id,
        'X-User-Region': 'cn',
        'User-Agent': USER_AGENT,
        'Content-Type': 'application/json',
    }
    req = urllib.request.Request(url, data=body.encode('utf-8'), headers=headers, method='POST')
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        err_body = e.read().decode('utf-8', errors='replace')
        raise RuntimeError(f"HTTP {e.code} {e.reason}\n{err_body}")


def send_checkin(token, device_id):
    """执行签到"""
    resp = invoke_trae_api(
        'https://api.trae.cn/trae/api/v2/ug/checkin_credits/claim',
        token, device_id, '{"req_source":1}',
    )
    if str(resp.get('code')) == '0':
        return '签到成功'
    return resp.get('message', '未知')


def get_checkin_status(token, device_id):
    """查询今日签到状态"""
    resp = invoke_trae_api(
        'https://api.trae.cn/trae/api/v2/ug/checkin_credits/status',
        token, device_id, '{"req_source":1}',
    )
    return '今日已签到' if resp.get('checked_in') is True else '今日未签到'


def get_credits(token, device_id):
    """查询积分额度"""
    resp = invoke_trae_api(
        'https://api.trae.cn/trae/api/v2/pay/user_current_entitlement_list',
        token, device_id, '{"require_usage":true,"full_data":true}',
    )
    usage = resp.get('usage_summary', {})
    consumed = usage.get('consumed_amount', 0)
    total = usage.get('total_amount', 0)
    available = int(float(total)) - int(float(consumed))
    return f"已用 {consumed} / 总计 {total} / 可用 {available}"


def main():
    parser = argparse.ArgumentParser(description='Trae CN 自动签到工具')
    parser.add_argument('--skip-checkin', action='store_true', help='跳过签到，仅查询状态')
    parser.add_argument('--local-check-only', action='store_true', help='仅本地检查 token，不请求服务器')
    args = parser.parse_args()

    # 检测已安装的 Trae
    detected = []
    for app_name in CANDIDATE_APPS:
        storage_path = os.path.join(
            os.environ.get('APPDATA', ''), app_name, 'User', 'globalStorage', 'storage.json'
        )
        if os.path.isfile(storage_path):
            detected.append(app_name)

    if not detected:
        print("未检测到 Trae，请确认已安装以下应用之一:\n" + "\n".join(CANDIDATE_APPS))
        _pause()
        return

    print("检测到 Trae:\n" + "\n".join(detected) + "\n")

    for app_name in detected:
        print(f"=== {app_name} ===")
        try:
            device_id = get_device_id(app_name)
            print(f"device_id: {device_id}")
            token = get_token(app_name)
            print(f"token 长度: {len(token)} 字符 / {len(token.split('.'))} 段")
            print(f"Token 过期: {get_token_expiry(token)}")

            if args.local_check_only:
                print("仅本地检查完成")
            else:
                print(f"当前积分: {get_credits(token, device_id)}")
                if not args.skip_checkin:
                    print(f"签到结果: {send_checkin(token, device_id)}")
                else:
                    print("已跳过签到 (--skip-checkin)")
                print(f"签到状态: {get_checkin_status(token, device_id)}")
                print(f"积分信息: {get_credits(token, device_id)}")
        except Exception as e:
            print(f"[{app_name}] 出错: {e}")
        print()

    _pause()


def _pause():
    try:
        input("\n按回车键退出...")
    except (EOFError, KeyboardInterrupt):
        pass


if __name__ == '__main__':
    main()