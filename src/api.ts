import * as https from 'https';

const USER_AGENT = 'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/50.0.2661.87 Safari/537.36';

function post(url: string, token: string, deviceId: string, body: string): Promise<any> {
    return new Promise((resolve, reject) => {
        const parsed = new URL(url);
        const options: https.RequestOptions = {
            hostname: parsed.hostname,
            path: parsed.pathname,
            method: 'POST',
            headers: {
                'Authorization': `Cloud-IDE-JWT ${token}`,
                'x-device-id': deviceId,
                'X-User-Region': 'cn',
                'User-Agent': USER_AGENT,
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(body),
            },
        };
        const req = https.request(options, (resp) => {
            let data = '';
            resp.on('data', (chunk: Buffer) => data += chunk.toString());
            resp.on('end', () => {
                try { resolve(JSON.parse(data)); }
                catch { reject(new Error(`JSON 解析失败: ${data}`)); }
            });
        });
        req.on('error', reject);
        req.write(body);
        req.end();
    });
}

export async function sendCheckin(token: string, deviceId: string): Promise<string> {
    const resp = await post(
        'https://api.trae.cn/trae/api/v2/ug/checkin_credits/claim',
        token, deviceId, '{"req_source":1}',
    );
    if (String(resp.code) === '0') return '签到成功';
    return resp.message || '未知';
}

export async function getCheckinStatus(token: string, deviceId: string): Promise<string> {
    const resp = await post(
        'https://api.trae.cn/trae/api/v2/ug/checkin_credits/status',
        token, deviceId, '{"req_source":1}',
    );
    return resp.checked_in === true ? '今日已签到' : '今日未签到';
}

export async function getCredits(token: string, deviceId: string): Promise<string> {
    const resp = await post(
        'https://api.trae.cn/trae/api/v2/pay/user_current_entitlement_list',
        token, deviceId, '{"require_usage":true,"full_data":true}',
    );
    const usage = resp.usage_summary || {};
    const consumed = usage.consumed_amount || 0;
    const total = usage.total_amount || 0;
    const available = Math.floor(Number(total)) - Math.floor(Number(consumed));
    return `已用 ${consumed} / 总计 ${total} / 可用 ${available}`;
}