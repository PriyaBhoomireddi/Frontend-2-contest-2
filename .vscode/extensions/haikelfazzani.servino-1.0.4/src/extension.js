const vscode = require('vscode');
const path = require('path');
const Servino = require('./Servino');

const wkPath = path.normalize(vscode.workspace.workspaceFolders[0].uri.path).trim();
let btnStartAndStopServer;
let servino = null;

function activate(context) {
	servino = Servino({ root: wkPath, wdir: wkPath, verbose: false });

	btnStartAndStopServer = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 200);
	context.subscriptions.push(btnStartAndStopServer);

	context.subscriptions.push(vscode.commands.registerCommand('servino.start', () => {
		servino.start();

		btnStartAndStopServer.color = "#FF518C";
		btnStartAndStopServer.command = 'servino.stop';
		btnStartAndStopServer.text = 'Stop Server | Servino';
		btnStartAndStopServer.tooltip = 'Stop Servino';
		btnStartAndStopServer.show();

		vscode.window.showInformationMessage('Servino is started');
	}));

	context.subscriptions.push(vscode.commands.registerCommand('servino.stop', () => {
		servino.stop();
		servino = null;

		btnStartAndStopServer.color = "#86F1FF";
		btnStartAndStopServer.command = 'servino.start';
		btnStartAndStopServer.text = 'Start Server | Servino';
		btnStartAndStopServer.tooltip = 'Start Servino';
		btnStartAndStopServer.show();

		vscode.window.showWarningMessage('Servino has been stopped.');
	}));
}

function deactivate() {
	if(servino) servino.stop();
	btnStartAndStopServer.dispose();
}

module.exports = {
	activate,
	deactivate
}