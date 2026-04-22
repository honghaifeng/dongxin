#import "DialogPlugin.h"
@import SpeechEngineToB;

@interface DialogPlugin () <SpeechEngineDelegate>
@property (nonatomic, strong) SpeechEngine *engine;
@property (nonatomic, copy) FlutterEventSink eventSink;
@end

@implementation DialogPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    // 初始化网络环境（SDK 要求 APP 生命周期内仅需执行一次）
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        BOOL ok = [SpeechEngine prepareEnvironment];
        NSLog(@"[DialogPlugin] prepareEnvironment: %@", ok ? @"OK" : @"FAILED");
    });

    FlutterMethodChannel *methodChannel =
        [FlutterMethodChannel methodChannelWithName:@"com.dongxin/dialog"
                                    binaryMessenger:[registrar messenger]];
    FlutterEventChannel *eventChannel =
        [FlutterEventChannel eventChannelWithName:@"com.dongxin/dialog_events"
                                  binaryMessenger:[registrar messenger]];

    DialogPlugin *instance = [[DialogPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:methodChannel];
    [eventChannel setStreamHandler:instance];
}

#pragma mark - FlutterPlugin

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    if ([@"init" isEqualToString:call.method]) {
        [self initEngine:call.arguments result:result];
    } else if ([@"start" isEqualToString:call.method]) {
        [self startEngine:call.arguments result:result];
    } else if ([@"stop" isEqualToString:call.method]) {
        [self stopEngine:result];
    } else if ([@"destroy" isEqualToString:call.method]) {
        [self destroyEngine:result];
    } else if ([@"sayHello" isEqualToString:call.method]) {
        [self sayHello:call.arguments result:result];
    } else if ([@"sendTextQuery" isEqualToString:call.method]) {
        [self sendTextQuery:call.arguments result:result];
    } else {
        result(FlutterMethodNotImplemented);
    }
}

#pragma mark - Engine Methods

- (void)initEngine:(NSDictionary *)args result:(FlutterResult)result {
    NSString *appId      = args[@"appId"] ?: @"";
    NSString *appKey     = args[@"appKey"] ?: @"";
    NSString *token      = args[@"token"] ?: @"";
    NSString *resourceId = args[@"resourceId"] ?: @"volc.speech.dialog";
    NSString *uid        = args[@"uid"] ?: @"dongxin_user";

    // 创建引擎实例（必须在主线程）
    if (self.engine == nil) {
        self.engine = [[SpeechEngine alloc] init];
        if (![self.engine createEngineWithDelegate:self]) {
            NSLog(@"[DialogPlugin] createEngine failed");
            result([FlutterError errorWithCode:@"CREATE_FAILED"
                                       message:@"createEngine failed"
                                       details:nil]);
            return;
        }
    }

    SpeechEngine *eng = self.engine;
    NSString *aecPath = [self aecModelPath];

    // 参数设置和初始化在后台执行，避免阻塞UI
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [eng setStringParam:SE_DIALOG_ENGINE forKey:SE_PARAMS_KEY_ENGINE_NAME_STRING];
        [eng setStringParam:appId forKey:SE_PARAMS_KEY_APP_ID_STRING];
        [eng setStringParam:appKey forKey:SE_PARAMS_KEY_APP_KEY_STRING];
        [eng setStringParam:token forKey:SE_PARAMS_KEY_APP_TOKEN_STRING];
        [eng setStringParam:resourceId forKey:SE_PARAMS_KEY_RESOURCE_ID_STRING];
        [eng setStringParam:uid forKey:SE_PARAMS_KEY_UID_STRING];
        [eng setStringParam:@"wss://openspeech.bytedance.com" forKey:SE_PARAMS_KEY_DIALOG_ADDRESS_STRING];
        [eng setStringParam:@"/api/v3/realtime/dialogue" forKey:SE_PARAMS_KEY_DIALOG_URI_STRING];

        // AEC 回声消除
        [eng setBoolParam:TRUE forKey:SE_PARAMS_KEY_ENABLE_AEC_BOOL];
        if (aecPath) {
            [eng setStringParam:aecPath forKey:SE_PARAMS_KEY_AEC_MODEL_PATH_STRING];
        }

        [eng setStringParam:SE_RECORDER_TYPE_RECORDER forKey:SE_PARAMS_KEY_RECORDER_TYPE_STRING];
        [eng setBoolParam:FALSE forKey:SE_PARAMS_KEY_DIALOG_ENABLE_PLAYER_BOOL];
        [eng setBoolParam:FALSE forKey:SE_PARAMS_KEY_DIALOG_ENABLE_RECORDER_AUDIO_CALLBACK_BOOL];
        [eng setBoolParam:FALSE forKey:SE_PARAMS_KEY_DIALOG_ENABLE_PLAYER_AUDIO_CALLBACK_BOOL];
        [eng setBoolParam:FALSE forKey:SE_PARAMS_KEY_DIALOG_ENABLE_DECODER_AUDIO_CALLBACK_BOOL];
        [eng setBoolParam:FALSE forKey:SE_PARAMS_KEY_ASR_AUTO_STOP_BOOL];
        [eng setBoolParam:TRUE forKey:SE_PARAMS_KEY_ASR_SHOW_UTTER_BOOL];
        [eng setBoolParam:TRUE forKey:SE_PARAMS_KEY_ASR_SHOW_PUNC_BOOL];
        [eng setStringParam:SE_ASR_RESULT_TYPE_FULL forKey:SE_PARAMS_KEY_ASR_RESULT_TYPE_STRING];
        [eng setIntParam:1800 forKey:SE_PARAMS_KEY_ASR_VAD_END_SILENCE_TIME_INT];
        [eng setStringParam:SE_LOG_LEVEL_WARN forKey:SE_PARAMS_KEY_LOG_LEVEL_STRING];

        SEEngineErrorCode ret = [eng initEngine];
        NSLog(@"[DialogPlugin] initEngine result: %d", ret);

        dispatch_async(dispatch_get_main_queue(), ^{
            if (ret == SENoError) {
                result(@(YES));
            } else {
                result([FlutterError errorWithCode:[NSString stringWithFormat:@"INIT_%d", ret]
                                           message:[NSString stringWithFormat:@"initEngine error code: %d", ret]
                                           details:nil]);
            }
        });
    });
}

- (void)startEngine:(NSDictionary *)args result:(FlutterResult)result {
    if (self.engine == nil) {
        result(@(NO));
        return;
    }

    NSString *botName       = args[@"botName"] ?: @"AI助手";
    NSString *systemRole    = args[@"systemRole"] ?: @"";
    NSString *speakingStyle = args[@"speakingStyle"] ?: @"";
    NSString *speaker       = args[@"speaker"] ?: @"";

    // 构建启动参数 JSON — system_role在dialog内, tts在根级
    NSMutableDictionary *dialogDict = [NSMutableDictionary dictionary];
    dialogDict[@"bot_name"] = botName;
    if (systemRole.length > 0) dialogDict[@"system_role"] = systemRole;
    if (speakingStyle.length > 0) dialogDict[@"speaking_style"] = speakingStyle;

    NSMutableDictionary *startDict = [NSMutableDictionary dictionary];
    startDict[@"dialog"] = dialogDict;
    if (speaker.length > 0) {
        startDict[@"tts"] = @{@"speaker": speaker};
    }

    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:startDict options:0 error:nil];
    NSString *startJson = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSLog(@"[DialogPlugin] startEngine: %@", startJson);

    SpeechEngine *eng = self.engine;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [eng sendDirective:SEDirectiveSyncStopEngine];
        SEEngineErrorCode ret = [eng sendDirective:SEDirectiveStartEngine data:startJson];
        NSLog(@"[DialogPlugin] startEngine result: %d", ret);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (ret == SENoError) {
                result(@(YES));
            } else {
                result([FlutterError errorWithCode:[NSString stringWithFormat:@"START_%d", ret]
                                           message:[NSString stringWithFormat:@"startEngine error code: %d", ret]
                                           details:nil]);
            }
        });
    });
}

- (void)stopEngine:(FlutterResult)result {
    if (self.engine) {
        SpeechEngine *eng = self.engine;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [eng sendDirective:SEDirectiveStopEngine];
        });
    }
    result(@(YES));
}

- (void)destroyEngine:(FlutterResult)result {
    if (self.engine) {
        SpeechEngine *eng = self.engine;
        self.engine = nil;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [eng destroyEngine];
            NSLog(@"[DialogPlugin] engine destroyed");
        });
    }
    result(@(YES));
}

- (void)sayHello:(NSDictionary *)args result:(FlutterResult)result {
    if (self.engine == nil) {
        result(@(NO));
        return;
    }
    NSString *content = args[@"content"] ?: @"";
    NSString *json = [NSString stringWithFormat:@"{\"content\":\"%@\"}", [self escapeJson:content]];
    SEEngineErrorCode ret = [self.engine sendDirective:SEDirectiveEventSayHello data:json];
    result(@(ret == SENoError));
}

- (void)sendTextQuery:(NSDictionary *)args result:(FlutterResult)result {
    if (self.engine == nil) {
        result(@(NO));
        return;
    }
    NSString *content = args[@"content"] ?: @"";
    NSString *json = [NSString stringWithFormat:@"{\"content\":\"%@\"}", [self escapeJson:content]];
    SEEngineErrorCode ret = [self.engine sendDirective:SEDirectiveEventChatTextQuery data:json];
    result(@(ret == SENoError));
}

#pragma mark - SpeechEngineDelegate

- (void)onMessageWithType:(SEMessageType)type andData:(NSData *)data {
    NSString *strData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
    NSString *event = nil;

    switch (type) {
        case SEEngineStart:
            event = @"engine_start";
            break;
        case SEEngineStop:
            event = @"engine_stop";
            break;
        case SEEngineError:
            event = @"error";
            NSLog(@"[DialogPlugin] SDK error: %@", strData);
            break;
        case SEDialogASRInfo:
            event = @"asr_start";
            break;
        case SEDialogASRResponse:
            event = @"asr_result";
            break;
        case SEDialogASREnded:
            event = @"asr_end";
            break;
        case SEDialogChatResponse:
            event = @"chat_response";
            break;
        case SEDialogChatEnded:
            event = @"chat_end";
            break;
        default:
            return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.eventSink) {
            self.eventSink(@{
                @"event": event,
                @"type": @(type),
                @"data": strData,
            });
        }
    });
}

#pragma mark - FlutterStreamHandler

- (FlutterError *)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)events {
    self.eventSink = events;
    return nil;
}

- (FlutterError *)onCancelWithArguments:(id)arguments {
    self.eventSink = nil;
    return nil;
}

#pragma mark - Helpers

- (NSString *)aecModelPath {
    NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"aec" ofType:@"model"];
    if (bundlePath == nil) return nil;

    NSString *docsDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *destPath = [docsDir stringByAppendingPathComponent:@"aec.model"];

    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:destPath]) {
        NSError *error;
        [fm copyItemAtPath:bundlePath toPath:destPath error:&error];
        if (error) {
            NSLog(@"[DialogPlugin] copy aec.model error: %@", error);
        }
    }
    return destPath;
}

- (NSString *)escapeJson:(NSString *)str {
    str = [str stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    str = [str stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    str = [str stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    str = [str stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
    str = [str stringByReplacingOccurrencesOfString:@"\t" withString:@"\\t"];
    return str;
}

@end
