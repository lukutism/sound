#import "RNSound.h"
#import "amr_wav_converter.h"

#if __has_include("RCTUtils.h")
#import "RCTUtils.h"
#else
#import <React/RCTUtils.h>
#endif

@implementation RNSound {
  NSMutableDictionary* _playerPool;
  NSMutableDictionary* _callbackPool;
}

@synthesize _key = _key;

- (void)audioSessionChangeObserver:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    AVAudioSessionRouteChangeReason audioSessionRouteChangeReason =
        [userInfo[@"AVAudioSessionRouteChangeReasonKey"] longValue];
    AVAudioSessionInterruptionType audioSessionInterruptionType =
        [userInfo[@"AVAudioSessionInterruptionTypeKey"] longValue];
    AVAudioPlayer *player = [self playerForKey:self._key];
    if (audioSessionInterruptionType == AVAudioSessionInterruptionTypeEnded) {
        if (player && player.isPlaying) {
            [player play];
        }
    }
    if (audioSessionRouteChangeReason ==
        AVAudioSessionRouteChangeReasonOldDeviceUnavailable) {
        if (player) {
            [player pause];
        }
    }
    if (audioSessionInterruptionType == AVAudioSessionInterruptionTypeBegan) {
        if (player) {
            [player pause];
        }
    }
}

-(NSMutableDictionary*) playerPool {
  if (!_playerPool) {
    _playerPool = [NSMutableDictionary new];
  }
  return _playerPool;
}

-(NSMutableDictionary*) callbackPool {
  if (!_callbackPool) {
    _callbackPool = [NSMutableDictionary new];
  }
  return _callbackPool;
}

-(AVAudioPlayer*) playerForKey:(nonnull NSNumber*)key {
  return [[self playerPool] objectForKey:key];
}

- (NSNumber *)keyForPlayer:(nonnull AVAudioPlayer *)player {
    return [[[self playerPool] allKeysForObject:player] firstObject];
}

-(RCTResponseSenderBlock) callbackForKey:(nonnull NSNumber*)key {
  return [[self callbackPool] objectForKey:key];
}

-(NSString *) getDirectory:(int)directory {
  return [NSSearchPathForDirectoriesInDomains(directory, NSUserDomainMask, YES) firstObject];
}

-(void) audioPlayerDidFinishPlaying:(AVAudioPlayer*)player
                       successfully:(BOOL)flag {
  NSNumber* key = [self keyForPlayer:player];
  if (key == nil) return;

  @synchronized(key) {
    RCTResponseSenderBlock callback = [self callbackForKey:key];
    if (callback) {
      callback(@[@(flag)]);
      [[self callbackPool] removeObjectForKey:key];
    }
  }
}

RCT_EXPORT_MODULE();

- (NSArray<NSString *> *)supportedEvents {
    return [NSArray arrayWithObjects:@"onPlayChange", nil];
}

- (NSDictionary *)constantsToExport {
    return [NSDictionary
        dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], @"IsAndroid",
                                     [[NSBundle mainBundle] bundlePath],
                                     @"MainBundlePath",
                                     [self getDirectory:NSDocumentDirectory],
                                     @"NSDocumentDirectory",
                                     [self getDirectory:NSLibraryDirectory],
                                     @"NSLibraryDirectory",
                                     [self getDirectory:NSCachesDirectory],
                                     @"NSCachesDirectory", nil];
}

RCT_EXPORT_METHOD(enable:(BOOL)enabled) {
  AVAudioSession *session = [AVAudioSession sharedInstance];
  [session setCategory: AVAudioSessionCategoryAmbient error: nil];
  [session setActive: enabled error: nil];
}

RCT_EXPORT_METHOD(setActive:(BOOL)active) {
  AVAudioSession *session = [AVAudioSession sharedInstance];
  [session setActive: active error: nil];
}

RCT_EXPORT_METHOD(setMode:(NSString *)modeName) {
  AVAudioSession *session = [AVAudioSession sharedInstance];
  NSString *mode = nil;

  if ([modeName isEqual: @"Default"]) {
    mode = AVAudioSessionModeDefault;
  } else if ([modeName isEqual: @"VoiceChat"]) {
    mode = AVAudioSessionModeVoiceChat;
  } else if ([modeName isEqual: @"VideoChat"]) {
    mode = AVAudioSessionModeVideoChat;
  } else if ([modeName isEqual: @"GameChat"]) {
    mode = AVAudioSessionModeGameChat;
  } else if ([modeName isEqual: @"VideoRecording"]) {
    mode = AVAudioSessionModeVideoRecording;
  } else if ([modeName isEqual: @"Measurement"]) {
    mode = AVAudioSessionModeMeasurement;
  } else if ([modeName isEqual: @"MoviePlayback"]) {
    mode = AVAudioSessionModeMoviePlayback;
  } else if ([modeName isEqual: @"SpokenAudio"]) {
    mode = AVAudioSessionModeSpokenAudio;
  }

  if (mode) {
    [session setMode: mode error: nil];
  }
}

RCT_EXPORT_METHOD(setCategory:(NSString *)categoryName
    mixWithOthers:(BOOL)mixWithOthers) {
  AVAudioSession *session = [AVAudioSession sharedInstance];
  NSString *category = nil;

  if ([categoryName isEqual: @"Ambient"]) {
    category = AVAudioSessionCategoryAmbient;
  } else if ([categoryName isEqual: @"SoloAmbient"]) {
    category = AVAudioSessionCategorySoloAmbient;
  } else if ([categoryName isEqual: @"Playback"]) {
    category = AVAudioSessionCategoryPlayback;
  } else if ([categoryName isEqual: @"Record"]) {
    category = AVAudioSessionCategoryRecord;
  } else if ([categoryName isEqual: @"PlayAndRecord"]) {
    category = AVAudioSessionCategoryPlayAndRecord;
  }
  #if TARGET_OS_IOS
  else if ([categoryName isEqual: @"AudioProcessing"]) {
      category = AVAudioSessionCategoryAudioProcessing;
  }
  #endif
    else if ([categoryName isEqual: @"MultiRoute"]) {
    category = AVAudioSessionCategoryMultiRoute;
  }

  if (category) {
    if (mixWithOthers) {
        [session setCategory: category withOptions:AVAudioSessionCategoryOptionMixWithOthers error: nil];
    } else {
      [session setCategory: category error: nil];
    }
  }
}

RCT_EXPORT_METHOD(enableInSilenceMode:(BOOL)enabled) {
  AVAudioSession *session = [AVAudioSession sharedInstance];
  [session setCategory: AVAudioSessionCategoryPlayback error: nil];
  [session setActive: enabled error: nil];
}

RCT_EXPORT_METHOD(prepare:(NSString*)fileName
                  withKey:(nonnull NSNumber*)key
                  withOptions:(NSDictionary*)options
                  withCallback:(RCTResponseSenderBlock)callback) {
  NSError* error;
  NSURL* fileNameUrl;
  AVAudioPlayer* player;

  if ([fileName hasPrefix:@"http"]) {
    fileNameUrl = [NSURL URLWithString:[fileName stringByRemovingPercentEncoding]];
    NSData* data = [NSData dataWithContentsOfURL:fileNameUrl];
    NSString *file = [[self getDirectory:NSCachesDirectory] stringByAppendingPathComponent:fileName.lastPathComponent];
    [data writeToFile:file atomically:YES];
    if ([file.pathExtension isEqualToString:@"amr"]) {
      NSString *amrFile = file;
      NSString *wavFile = [[amrFile stringByDeletingPathExtension] stringByAppendingPathExtension:@"wav"];
      int frameCount = amr_file_to_wave_file([amrFile cStringUsingEncoding:NSASCIIStringEncoding],
                            [wavFile cStringUsingEncoding:NSASCIIStringEncoding]);
      if (frameCount != 0) {
        data = [NSData dataWithContentsOfFile:wavFile];
      }
    }
    player = [[AVAudioPlayer alloc] initWithData:data error:&error];
  }
  else {
    fileNameUrl = [NSURL fileURLWithPath:[fileName stringByRemovingPercentEncoding]];
    if ([fileName.pathExtension isEqualToString:@"amr"]) {
      NSString *amrFile = fileName;
      NSString *wavFile = [[amrFile stringByDeletingPathExtension] stringByAppendingPathExtension:@"wav"];
      int frameCount = amr_file_to_wave_file([amrFile cStringUsingEncoding:NSASCIIStringEncoding],
                            [wavFile cStringUsingEncoding:NSASCIIStringEncoding]);
      if (frameCount != 0) {
        fileNameUrl = [NSURL fileURLWithPath:wavFile];
      }
    }
    player = [[AVAudioPlayer alloc]
              initWithContentsOfURL:fileNameUrl
              error:&error];
  }

  if (player) {
    player.delegate = self;
    player.enableRate = YES;
    [player prepareToPlay];
    [[self playerPool] setObject:player forKey:key];
    callback(@[[NSNull null], @{@"duration": @(player.duration),
                                @"numberOfChannels": @(player.numberOfChannels)}]);
  } else {
    callback(@[RCTJSErrorFromNSError(error)]);
  }
}

RCT_EXPORT_METHOD(play:(nonnull NSNumber*)key withCallback:(RCTResponseSenderBlock)callback) {
  AVAudioPlayer* player = [self playerForKey:key];
  if (player) {
    [[self callbackPool] setObject:[callback copy] forKey:key];
    [player play];
  }
}

RCT_EXPORT_METHOD(pause:(nonnull NSNumber*)key withCallback:(RCTResponseSenderBlock)callback) {
  AVAudioPlayer* player = [self playerForKey:key];
  if (player) {
    [player pause];
    callback(@[]);
  }
}

RCT_EXPORT_METHOD(stop:(nonnull NSNumber*)key withCallback:(RCTResponseSenderBlock)callback) {
  AVAudioPlayer* player = [self playerForKey:key];
  if (player) {
    [player stop];
    player.currentTime = 0;
    callback(@[]);
  }
}

RCT_EXPORT_METHOD(release:(nonnull NSNumber*)key) {
  AVAudioPlayer* player = [self playerForKey:key];
  if (player) {
    [player stop];
    [[self callbackPool] removeObjectForKey:player];
    [[self playerPool] removeObjectForKey:key];
  }
}

RCT_EXPORT_METHOD(setVolume:(nonnull NSNumber*)key withValue:(nonnull NSNumber*)value) {
  AVAudioPlayer* player = [self playerForKey:key];
  if (player) {
    player.volume = [value floatValue];
  }
}

RCT_EXPORT_METHOD(setPan:(nonnull NSNumber*)key withValue:(nonnull NSNumber*)value) {
  AVAudioPlayer* player = [self playerForKey:key];
  if (player) {
    player.pan = [value floatValue];
  }
}

RCT_EXPORT_METHOD(setNumberOfLoops:(nonnull NSNumber*)key withValue:(nonnull NSNumber*)value) {
  AVAudioPlayer* player = [self playerForKey:key];
  if (player) {
    player.numberOfLoops = [value intValue];
  }
}

RCT_EXPORT_METHOD(setSpeed:(nonnull NSNumber*)key withValue:(nonnull NSNumber*)value) {
  AVAudioPlayer* player = [self playerForKey:key];
  if (player) {
    player.rate = [value floatValue];
  }
}


RCT_EXPORT_METHOD(setCurrentTime:(nonnull NSNumber*)key withValue:(nonnull NSNumber*)value) {
  AVAudioPlayer* player = [self playerForKey:key];
  if (player) {
    player.currentTime = [value doubleValue];
  }
}

RCT_EXPORT_METHOD(getCurrentTime:(nonnull NSNumber*)key
                  withCallback:(RCTResponseSenderBlock)callback) {
  AVAudioPlayer* player = [self playerForKey:key];
  if (player) {
    callback(@[@(player.currentTime), @(player.isPlaying)]);
  } else {
    callback(@[@(-1), @(false)]);
  }
}

@end
