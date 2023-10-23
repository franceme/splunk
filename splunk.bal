import ballerina/http;
import ballerina/log;
import ballerina/io;
import ballerina/os;
import ballerina/file;
import ballerina/regex;

isolated Client? wrapper = ();

isolated string? cccollectionKey = ();
isolated boolean ccverify = true;
isolated string? backupJsonlFile = ();

public isolated function setBackupJsonlFile(string input) {
    lock {
        backupJsonlFile = input;
    }
}

public isolated function setCollectionKey(string input) {
    lock {
        cccollectionKey = input;
    }
}

public isolated function setVerify(boolean input) {
    lock {
        ccverify = input;
    }
}

public isolated function getClient() returns Client|error {
    Client output = check new ("");
    lock {
        output = wrapper ?: output;
    }
    return output;
}

public isolated function setClient(Client runner) {
    lock {
        wrapper = runner;
    }
}

public isolated client class Client {
    public final http:Client clientEp;
    private final string collectionKey;
    private final string hostName;
    private final string index;

    # Gets invoked to initialize the `connector`.
    #
    # + config - The configurations to be used when initializing the `connector` 
    # + serviceUrl - URL of the target service 
    # + return - An error if connector initialization failed 
    public isolated function init(string? collectionKey, string serviceUrl = "https://127.0.0.1:8088/", int timeoutS = 20 * 60, string index = "main", string hostName = os:getUsername(), boolean verify = true) returns error? {

        http:ClientConfiguration httpClientConfig = {
            timeout: <decimal>timeoutS
        };

        boolean realVerify = true;
        lock {
            realVerify = verify || ccverify;
        }
        if !realVerify {
            httpClientConfig["secureSocket"] = {
                enable: false,
                verifyHostName: false
            };
            httpClientConfig["validation"] = false;
        }

        self.clientEp = check new (serviceUrl, httpClientConfig);

        lock {
            self.collectionKey = collectionKey ?: cccollectionKey ?: "";
        }

        self.hostName = hostName;
        self.index = index;

        return;
    }

    private isolated function headers() returns map<string> {
        return {
            "Authorization": "Splunk " + self.collectionKey,
            "X-Splunk-Request-Channel": "e58ed763-928c-4155-bee9-fdbaaadc15f3"
        };
    }

    private isolated function body(string eventString) returns map<string> {
        return {
            "index": self.index,
            "host": self.hostName,
            "event": eventString
        };
    }

    resource isolated function get .() returns boolean {
        http:Response|http:ClientError response = self.clientEp->/services/collector/event.post(
            message = {},
            headers = self.headers()
        );

        return !(response is error);
    }

    resource isolated function post .(*log:KeyValues rawdata) returns boolean {
        map<string> raw = {};
        foreach [string, any] [key, value] in rawdata.entries() {
            raw[key] = value.toString();
        }

        http:Response|http:ClientError response = self.clientEp->/services/collector/event.post(
            message = self.body(raw.toJsonString()),
            headers = self.headers()
        );

        lock {
            if backupJsonlFile != () {
                string[] fileContents = [];

                boolean|file:Error fileExists = file:test(backupJsonlFile ?: "", file:EXISTS);
                if !(fileExists is error) && fileExists {
                    string[]|error rawFileContents = io:fileReadLines(backupJsonlFile ?: "");
                    if !(rawFileContents is error) {
                        fileContents.push(...rawFileContents);
                    }
                }

                fileContents.push(regex:replaceAll(raw.toJsonString(), "\n", ""));
                io:Error? fileWriteLines = io:fileWriteLines(backupJsonlFile ?: "", fileContents);
                if fileWriteLines is error {
                    io:println("Error Writing File Content");
                }
            }
        }

        return !(response is error);
    }
}
