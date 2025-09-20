//
//  main.m
//  Extension
//
//  Created by Zimry Ong on 4.12.2020.
//
#include <Foundation/Foundation.h>
#include <CommonCrypto/CommonDigest.h>
#include <EndpointSecurity/EndpointSecurity.h>
#include <dispatch/queue.h>
#include <stdio.h>
#include <bsm/libbsm.h>
#include <os/log.h>

#include "NSDataHash.h"
#include "NSDataSSDEEP.h"

static dispatch_queue_t g_event_queue = NULL;


static void init_dispatch_queue(void)
{
    // Choose an appropriate Quality of Service class appropriate for your app.
    // https://developer.apple.com/documentation/dispatch/dispatchqos
    dispatch_queue_attr_t queue_attrs = dispatch_queue_attr_make_with_qos_class(
            DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_USER_INITIATED, 0);

    g_event_queue = dispatch_queue_create("event_queue", queue_attrs);
}

NSString* esstring_to_nsstring(const es_string_token_t *es_string_token) {
    NSString *res = @"";
    
    if (es_string_token && es_string_token->data && es_string_token->length > 0) {
        // es_string_token->data is a pointer to a null-terminated string
        res = [NSString stringWithUTF8String:es_string_token->data];
    }
    
    return res;
}

static void handle_exec(es_client_t *client, const es_message_t *msg)
{
    //NSMutableString *client_meta = [NSMutableString string];
    NSMutableString *client_meta = [[NSMutableString alloc] init];
    
    const es_process_t *proc = msg->event.exec.target;
    uint32_t argCount = es_exec_arg_count(&msg->event.exec);
    
    
    [client_meta appendString:@"{"];
    
    [client_meta appendFormat:@"\"timestamp\":\"%@\",", [NSDate date]];
    [client_meta appendString:@"\"event_type\":\"ES_EVENT_TYPE_AUTH_EXEC\","];
    [client_meta appendFormat:@"\"pid\":%d,", audit_token_to_pid(msg->process->audit_token)];
    [client_meta appendFormat:@"\"path\":\"%@\",", esstring_to_nsstring(&proc->executable->path)];
    
    
    //-----------------------------
    //argc, argv
    [client_meta appendFormat:@"\"argCount\":%u,", argCount];
    [client_meta appendString:@"\"arguments:\"["];
    for(uint32_t i = 0; i < argCount; i++) {
        es_string_token_t arg = es_exec_arg(&msg->event.exec, i);
        if (i == (argCount - 1)) {
            [client_meta appendFormat:@"\"%@\"", esstring_to_nsstring(&arg)];
        } else {
            [client_meta appendFormat:@"\"%@\",", esstring_to_nsstring(&arg)];
        }
    }
    [client_meta appendString:@"],"];
    
    //-----------------------------
    //compute the hashes (sha256 and dssdeep)
    NSString *path =  [[NSString alloc] initWithFormat:@"%@", esstring_to_nsstring(&proc->executable->path)];
    NSFileManager *filemgr;
    NSData *databuffer;
    filemgr = [NSFileManager defaultManager];
    databuffer = [filemgr contentsAtPath: path ];
    NSString *hash_sha256 = [[NSData dataWithBytes:databuffer.bytes length:databuffer.length] SHA256String];
    NSString *hash_ssdeep = [[NSData dataWithBytes:databuffer.bytes length:databuffer.length] SSDEEPHash];
    
    [client_meta appendFormat:@"\"sha256\":\"%@\",", hash_sha256];
    [client_meta appendFormat:@"\"ssdeep\":\"%@\",", hash_ssdeep];
    [client_meta appendFormat:@"\"file_size\":%lu,", databuffer.length];
    
    
    [client_meta appendFormat:@"\"signing_id\":\"%@\",", esstring_to_nsstring(&proc->signing_id)];
    [client_meta appendFormat:@"\"team_id\":\"%@\"", esstring_to_nsstring(&proc->team_id)];
    [client_meta appendString:@"}"];
    
    const char *preview = [client_meta UTF8String];
    os_log(OS_LOG_DEFAULT, "%{public}s", preview);
    
    // test
    //static const char *signing_id_to_block = "com.apple.calculator";
    static const char *sha256_to_block = "0a557177175c8df2e39d4978eedc56433a2499eda5d606f28f24c80d2010d262";
    const char *file_hash = [hash_sha256 UTF8String];

    if (strcmp(file_hash, sha256_to_block) == 0) {
        es_respond_auth_result(client, msg, ES_AUTH_RESULT_DENY, true);
        os_log(OS_LOG_DEFAULT, "DENIED");
    } else {
        es_respond_auth_result(client, msg, ES_AUTH_RESULT_ALLOW, true);
    }
}

static void handle_event(es_client_t *client, const es_message_t *msg)
{

    switch (msg->event_type) {
        case ES_EVENT_TYPE_AUTH_EXEC:
            handle_exec(client, msg);
            break;

        default:
            if (msg->action_type == ES_ACTION_TYPE_AUTH) {
                es_respond_auth_result(client, msg, ES_AUTH_RESULT_ALLOW, true);
            }
            break;
    }
}

int main(int argc, char *argv[])
{
    
    init_dispatch_queue();
    
    // Create the client
    es_client_t *client = NULL;
    es_new_client_result_t newClientResult = es_new_client(&client, ^(es_client_t *c, const es_message_t *msg) {
        // Do processing on the message received
        handle_event(c, msg);
    });

    if (newClientResult != ES_NEW_CLIENT_RESULT_SUCCESS) {
        os_log_error(OS_LOG_DEFAULT, "Failed to create the ES client: %d", newClientResult);
        return 1;
    }
    
    // set authorized events to be subscibed.
    es_event_type_t events[] = { ES_EVENT_TYPE_AUTH_EXEC };
    if (es_subscribe(client, events, sizeof(events) / sizeof(events[0])) != ES_RETURN_SUCCESS) {
        os_log_error(OS_LOG_DEFAULT, "Failed to subscribe to events");
        es_delete_client(client);
        return 1;
    }
    
    dispatch_main();
}
