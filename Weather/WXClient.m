//
//  WXClient.m
//  Weather
//
//  Created by Eric on 9/15/14.
//  Copyright (c) 2014 edu.self. All rights reserved.
//

#import "WXClient.h"
#import "WXCondition.h"
#import "WXDailyForecast.h"

@interface WXClient()

@property (nonatomic, strong) NSURLSession *session;

@end

@implementation WXClient

- (id)init
{
    if (self = [super init]) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        _session = [NSURLSession sessionWithConfiguration:config];
    }
    return self;
}

- (RACSignal *)fetchJSONFromURL:(NSURL *)url
{
    NSLog(@"Fetching: %@", url.absoluteString);
    
    // Return the signal.
    return [[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        
        // Create NSURL Session Data Task
        NSURLSessionDataTask *dataTask = [self.session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (!error) {
                NSError *jsonError = nil;
                id json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
                if (!jsonError) {
                    // When JSON data exists and there are no errors, send the subscriber the JSON serialized as either an array or dictionary.
                    [subscriber sendNext:json];
                }
                else {
                    // If there is an error, notify the subscriber.
                    [subscriber sendError:jsonError];
                }
            }
            else {
                // Notify subscriber of error.
                [subscriber sendError:error];
            }
            
            // Let subscriber know the request has completed.
            [subscriber sendCompleted];
        }];
        
        // Start the network request once the signal is subscribed to.
        [dataTask resume];
        
        // Handle cleanup when signal is destroyed.
        return [RACDisposable disposableWithBlock:^{
            [dataTask cancel];
        }];
    }] doError:^(NSError *error) {
            // Log any errors that occur.
            NSLog(@"%@", error);
    }];
}

- (RACSignal *)fetchCurrentConditionsForLocation:(CLLocationCoordinate2D)coordinate
{
    // Format the URL from the coordinate object using its latitude and longitude.
    NSString *urlString = [NSString stringWithFormat:@"http://api.openweathermap.org/data/2.5/weather?lat=%f&lon=%f&units=imperial", coordinate.latitude, coordinate.longitude];
    NSURL *url = [NSURL URLWithString:urlString];
    
    // Create the signal.
    return [[self fetchJSONFromURL:url] map:^(NSDictionary *json) {
        // Convert the JSON to a WXCondition object.
        return [MTLJSONAdapter modelOfClass:[WXCondition class] fromJSONDictionary:json error:nil];
    }];
}

- (RACSignal *)fetchHourlyForecastForLocation:(CLLocationCoordinate2D)coordinate
{
    NSString *urlString = [NSString stringWithFormat:@"http://api.openweathermap.org/data/2.5/forecast?lat=%f&lon=%f&units=imperial&cnt=12", coordinate.latitude, coordinate.longitude];
    NSURL *url = [NSURL URLWithString:urlString];
    
    // Create the signal.
    return [[self fetchJSONFromURL:url] map:^(NSDictionary *json) {
        // Build RACSequence from the list key of JSON.
        RACSequence *list = [json[@"list"] rac_sequence];
        
        // Map the new list of objects.
        return [[list map:^(NSDictionary *item) {
            // Convert JSON into a WXCondition object.
            return [MTLJSONAdapter modelOfClass:[WXCondition class] fromJSONDictionary:item error:nil];
            // Get data as NSArray.
        }] array];
    }];
}

- (RACSignal *)fetchDailyForecastForLocation:(CLLocationCoordinate2D)coordinate
{
    NSString *urlString = [NSString stringWithFormat:@"http://api.openweathermap.org/data/2.5/forecast/daily?lat=%f&lon=%f&units=imperial&cnt=7", coordinate.latitude, coordinate.longitude];
    NSURL *url = [NSURL URLWithString:urlString];
    
    // Use generic fetch method and map results to convert into an array of Mantle objects
    return [[self fetchJSONFromURL:url] map:^(NSDictionary *json) {
        // Build a sequence from the list of raw JSON
        RACSequence *list = [json[@"list"] rac_sequence];
        
        // Use a function to map results from the JSON to Mantle objects
        return [[list map:^(NSDictionary *item) {
            return [MTLJSONAdapter modelOfClass:[WXDailyForecast class] fromJSONDictionary:item error:nil];
        }] array];
    }];
}


@end
