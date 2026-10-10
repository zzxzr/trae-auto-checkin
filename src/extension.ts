import * as vscode from 'vscode';
import { detectApps, getDeviceId, getToken } from './config';
import { getTokenExpiry } from './crypto';
import { sendCheckin, getCheckinStatus, getCredits } from './api';

let outputChannel: vscode.OutputChannel;

export function activate(context: vscode.ExtensionContext) {
    outputChannel = vscode.window.createOutputChannel('Trae Auto Checkin');
    context.subscriptions.push(outputChannel);

    context.subscriptions.push(
        vscode.commands.registerCommand('traeAutoCheckin.checkin', () => runCheckin(false))
    );
    context.subscriptions.push(
        vscode.commands.registerCommand('traeAutoCheckin.status', () => runCheckin(true))
    );

    const config = vscode.workspace.getConfiguration('traeAutoCheckin');
    if (config.get<boolean>('autoCheckinOnStartup', true)) {
        const delay = config.get<number>('startupDelay', 5) * 1000;
        setTimeout(() => runCheckin(false), delay);
    }
}

async function runCheckin(skipCheckin: boolean) {
    const apps = detectApps();
    if (apps.length === 0) {
        vscode.window.showWarningMessage('未检测到 Trae CN，请确认已安装并登录');
        return;
    }

    const config = vscode.workspace.getConfiguration('traeAutoCheckin');
    const showOnSuccess = config.get<boolean>('showOutputOnSuccess', false);
    let hasError = false;

    outputChannel.clear();

    for (const appName of apps) {
        outputChannel.appendLine(`=== ${appName} ===`);
        try {
            const deviceId = getDeviceId(appName);
            const token = getToken(appName);
            outputChannel.appendLine(`device_id: ${deviceId}`);
            outputChannel.appendLine(`Token 过期: ${getTokenExpiry(token)}`);
            outputChannel.appendLine(`当前积分: ${await getCredits(token, deviceId)}`);

            if (!skipCheckin) {
                const result = await sendCheckin(token, deviceId);
                outputChannel.appendLine(`签到结果: ${result}`);
                const credits = await getCredits(token, deviceId);
                vscode.window.showInformationMessage(`Trae 签到: ${result}!(积分信息: ${credits})`);
            } else {
                outputChannel.appendLine('已跳过签到 (仅查询)');
            }

            outputChannel.appendLine(`签到状态: ${await getCheckinStatus(token, deviceId)}`);
            outputChannel.appendLine(`积分信息: ${await getCredits(token, deviceId)}`);
        } catch (e: any) {
            hasError = true;
            outputChannel.appendLine(`出错: ${e.message}`);
        }
        outputChannel.appendLine('');
    }

    if (hasError || showOnSuccess) {
        outputChannel.show(true);
    }
}

export function deactivate() {}