import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import { decryptAuthInfo } from './crypto';

const CANDIDATE_APPS = ['Trae CN', 'TRAE SOLO CN'];

function appDataPath(): string {
    return process.env.APPDATA || path.join(os.homedir(), 'AppData', 'Roaming');
}

function programDataPath(): string {
    return process.env.ProgramData || 'C:\\ProgramData';
}

export function getDeviceId(appName: string): string {
    const candidates = [
        path.join(appDataPath(), appName, 'ahanet', 'tt_net_config.config'),
        path.join(programDataPath(), appName, 'ahanet', 'tt_net_config.config'),
    ];
    const configPath = candidates.find(p => fs.existsSync(p));
    if (!configPath) throw new Error('未找到 tt_net_config.config');

    const config = fs.readFileSync(configPath, 'ascii');
    const marker = 'device_id&#*';
    const start = config.indexOf(marker);
    if (start < 0) throw new Error('配置文件中未找到 device_id 标记');
    const idStart = start + marker.length;
    let end = config.indexOf('@', idStart);
    if (end < 0) end = config.length;
    const deviceId = config.substring(idStart, end).trim();
    if (!deviceId) throw new Error('device_id 为空');
    return deviceId;
}

export function getToken(appName: string): string {
    const storagePath = path.join(appDataPath(), appName, 'User', 'globalStorage', 'storage.json');
    if (!fs.existsSync(storagePath)) throw new Error('未找到 storage.json');

    const storage = JSON.parse(fs.readFileSync(storagePath, 'utf-8'));
    const authInfo = storage['iCubeAuthInfo://icube.cloudide'];
    if (!authInfo) throw new Error('storage.json 中未找到 iCubeAuthInfo');

    const jsonText = decryptAuthInfo(authInfo);
    const token = JSON.parse(jsonText).token;
    if (!token) throw new Error('JSON 中未找到 token');
    return token;
}

export function detectApps(): string[] {
    return CANDIDATE_APPS.filter(appName => {
        const p = path.join(appDataPath(), appName, 'User', 'globalStorage', 'storage.json');
        return fs.existsSync(p);
    });
}