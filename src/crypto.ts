import * as crypto from 'crypto';

const XOR_DATA = Buffer.from([
    77, 212, 194, 230, 184, 49, 98, 9, 14, 82, 179, 199, 166, 115, 59, 164,
    28, 178, 70, 43, 130, 154, 181, 138, 25, 107, 57, 219, 87, 23, 117, 36,
    244, 155, 175, 127, 8, 232, 214, 141, 38, 167, 46, 55, 193, 169, 90, 47,
    31, 5, 165, 24, 146, 174, 242, 148, 151, 50, 182, 42, 56, 170, 221, 88,
]);

export function decryptAuthInfo(base64Text: string): string {
    const t = Buffer.from(base64Text, 'base64');
    if (t.length < 38) throw new Error('iCubeAuthInfo 数据长度不足 38');

    const key = t.subarray(6, 38);
    const shaKey = crypto.createHash('sha512').update(key).digest();
    const h = crypto.createHash('sha512').update(Buffer.concat([shaKey, XOR_DATA])).digest();

    const aesKey = h.subarray(0, 16);
    const iv = h.subarray(16, 32);
    const cipher = t.subarray(38);

    const decipher = crypto.createDecipheriv('aes-128-cbc', aesKey, iv);
    decipher.setAutoPadding(false);
    let plain = Buffer.concat([decipher.update(cipher), decipher.final()]);

    const pad = plain[plain.length - 1];
    if (pad >= 1 && pad <= 16 && pad <= plain.length) {
        plain = plain.subarray(0, plain.length - pad);
    }

    if (plain.length <= 64) throw new Error('解密后数据过短，不是有效 JSON');
    return plain.subarray(64).toString('utf-8');
}

export function getTokenExpiry(token: string): string {
    const parts = token.split('.');
    if (parts.length !== 3) return '';
    let payload = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    payload += '='.repeat((4 - (payload.length % 4)) % 4);
    try {
        const raw = Buffer.from(payload, 'base64').toString('utf-8');
        const exp = JSON.parse(raw).exp;
        if (!exp) return '';
        const now = Math.floor(Date.now() / 1000);
        const remain = exp - now;
        if (remain <= 0) return '已过期';
        const days = Math.floor(remain / 86400);
        const hours = Math.floor((remain % 86400) / 3600);
        return `剩余 ${days} 天 ${hours} 小时`;
    } catch {
        return '';
    }
}