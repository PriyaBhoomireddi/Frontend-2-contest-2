import os, re, sys, stat, argparse, json, io
import subprocess
import shutil
import logging
import time
LOG_FORMAT = "%(asctime)-15s %(levelname)6s  : %(message)s"
logFileName = os.path.join(os.path.expanduser("~"), "ServerConfigUpdater.log")
logging.basicConfig(filename=logFileName,level=logging.DEBUG, format=LOG_FORMAT)

# Used for Fusion 360 to automaitcally switch server config (dev, fdev, stating, etc.) environments
# Usages: 
# python ServerConfigUpdater.py appProcessId newConfigPath configPath localCachePath 
# Examples: 
# python "Neutron/UI/Components/Resources/DataTextCommands/ServerConfigUpdater.py" 
#   34824 "Debug/Fusion360.exe" 
#   "Application/ApplicationOptions.dev.xml" "Debug/Fusion 360.server.config" 
#   "C:/Users/zhanglo/AppData/Local/Autodesk"
# 
def printInfo(msg):
    logging.info(msg)
    print(msg)

def printError(msg):
    logging.error(msg)
    print(msg)
    print("Please check details or contact Lori Zhang for details, thanks!")

def closeApp(appProcessId):
    printInfo("--- Close Fusion 360: " + appProcessId)
    if sys.platform == 'win32':
        cmd = "taskkill /f /pid " + appProcessId
    else:
        cmd = "kill -9 " + appProcessId

    logging.debug("run cmd: " + cmd)
    ret = subprocess.call(cmd, shell=True)
    # sleep x seconds to wait for like fusion full terminated
    time.sleep(3) 
    if ret == 0:
        return True
    return False

def startApp(appPath):
    printInfo("--- Start Fusion 360: " + appPath)
    if sys.platform == 'win32':
        cmd = [appPath]
        logging.debug("run cmd: " + str(cmd))
        try:
            subprocess.Popen(cmd)
        except OSError as e:
            printError(str(e))
            return False
    else:
        cmdTemp = "open \"" + appPath + "\""
        logging.debug("run cmd: " + cmdTemp)
        ret = subprocess.call(cmdTemp, shell=True)
        if ret != 0:
            return False

    time.sleep(3) 
    return True

def updateConfigFile(newConfigPath, configPath):
    printInfo("--- Update server config")
    printInfo("the new  config: " + newConfigPath)
    printInfo("override target: " + configPath)
    try:
        shutil.copyfile(newConfigPath, configPath)
    except IOError as e:
        printError("The target config file as below is not writable, please check it!")
        printError(configPath)
        return False
    except Error as e:
        printError("Failed to update config path!")
        return False
    return True

def deleteFolder(folderPath):
    printInfo("Delete folder: " + folderPath)
    if not os.path.exists(folderPath):
        return True
    shutil.rmtree(folderPath, ignore_errors=True)

    if os.path.exists(folderPath):
        logging.warning("Warning: folder isn't deleted successfully, please double check!")
        logging.warning(folderPath)
    return True

def clearLocalCache(localCachePath):
    printInfo("--- Clear local cache: login state")
    webServicesFolder = os.path.join(localCachePath, "Web Services")
    deleteFolder(webServicesFolder)

    return True

def startUpdate(appPath, appProcessId, newConfigPath, configPath, localCachePath):
    if not closeApp(appProcessId):
        printError("Failed to close app with process Id: " + appProcessId)
        return False

    if not updateConfigFile(newConfigPath, configPath):
        printError("Failed to update config file!")
        return False

    if not clearLocalCache(localCachePath):
        printError("Failed to clear local cache!")
        return False

    if not startApp(appPath):
        printError("Failed to start app!")
        return False
    
    printInfo("--- Success updated server config!")
    return True

if __name__ == '__main__':
    printInfo("\n\n---------------- Start Fusion server config updater ----------------")
    argparser = argparse.ArgumentParser(description = 'Fusion server config updater.')
    argparser.add_argument('appProcessId',
            help = 'Fusion 360 application file path')
    argparser.add_argument('appPath', help = 'Fusion app path')
    argparser.add_argument('newConfigPath', help = 'New Fusion server config file path')
    argparser.add_argument('configPath', help = 'Fusion 360.server.config file path')
    argparser.add_argument('localCachePath', help = 'Fusion local cache folder path')
    parsed_args = argparser.parse_args()
    
    logging.debug("Python version: " + sys.version)
    logging.debug(parsed_args)

    success = startUpdate(parsed_args.appPath,
                        parsed_args.appProcessId,
                        parsed_args.newConfigPath, 
                        parsed_args.configPath,
                        parsed_args.localCachePath)
    
    logging.shutdown()
    if not success:
        os.system("ServerConfigUpdater.log")        

    time.sleep(2)
    sys.exit(success)
