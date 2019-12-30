//
//  SCXAudioFile.h
//  SCXAudioFIlePlayer
//
//  Created by 孙承秀 on 2019/12/25.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
NS_ASSUME_NONNULL_BEGIN

@interface SCXAudioFile : NSObject

/**
 available
 */
@property(nonatomic , assign , readonly)BOOL available;


/**
 file path
 */
@property(nonatomic , copy , readonly)NSString *filePath;

/**
 asbd
 */
@property(nonatomic , assign , readonly)AudioStreamBasicDescription format;

/**
 file size
 */
@property(nonatomic , assign , readonly)unsigned long long fileSize;

/**
 duration
 */
@property(nonatomic , assign , readonly)NSTimeInterval duration;

/**
 bit rate
 */
@property(nonatomic , assign , readonly)uint32_t bitRate;

/**
 max pack size
 */
@property(nonatomic , assign , readonly)uint32_t maxPacketSize;

/**
 audio data byte count
 */
@property(nonatomic , assign , readonly)uint64_t audioDataByteCount;

/// 初始化
/// @param filePath 音频路径
- (instancetype)initWithFilePath:(NSString *)filePath;

/// 解析数据
/// @param stop 是否停止
- (NSArray *)parseData:(BOOL *)stop;

/// 查找 magic cookie
- (NSData *)fetchMagicCookie;

/// seek 到指定的时间
/// @param time 时间点
- (void)seekToTime:(NSTimeInterval)time;

/// 关闭
- (void)close;
@end

NS_ASSUME_NONNULL_END
