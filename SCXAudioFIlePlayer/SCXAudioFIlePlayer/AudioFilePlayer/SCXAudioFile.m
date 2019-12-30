//
//  SCXAudioFile.m
//  SCXAudioFIlePlayer
//
//  Created by 孙承秀 on 2019/12/25.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import "SCXAudioFile.h"
#import "SCXAudioData.h"
static const UInt32 packetPerRead = 15;
@interface SCXAudioFile()
{
    NSFileHandle *_fileHandle;
    AudioFileID _audioFileId;
    NSTimeInterval _packetDuration;
    SInt64 _dataOffset;
}
@end
@implementation SCXAudioFile
-(instancetype)initWithFilePath:(NSString *)filePath{
    if (self = [super init]) {
        _filePath = filePath;
        _fileHandle = [NSFileHandle fileHandleForReadingAtPath:filePath];
        _fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil] fileSize];
        if (_fileHandle && _fileSize > 0) {
            if ([self openAudioFile]) {
                [self fetchFormatInfo];
            }
        } else {
            [_fileHandle closeFile];
        }
    }
    return self;
}
- (BOOL)openAudioFile{
    OSStatus status = AudioFileOpenWithCallbacks((__bridge void *)self, scx_AudioFile_ReadProc, NULL, scx_audioFile_GetSizeProc, NULL, 0, &_audioFileId);
    if (status != noErr) {
        return NO;
    }
    return YES;
}
- (void)fetchFormatInfo{
    uint32_t formatListSize;
    OSStatus status = AudioFileGetPropertyInfo(_audioFileId, kAudioFilePropertyFormatList, &formatListSize, NULL);
    if (status == noErr) {
        AudioFormatListItem *formatList = malloc(formatListSize);
        BOOL found = NO;
        status = AudioFileGetProperty(_audioFileId, kAudioFilePropertyFormatList, &formatListSize, &formatList);
        if (status == noErr) {
            uint32_t supportFormatSize;
            status = AudioFormatGetPropertyInfo(kAudioFormatProperty_DecodeFormatIDs, 0, NULL, &supportFormatSize);
            if (status != noErr) {
                free(formatList);
                [self closeAudioFile];
                return;
            }
            uint32_t formatCount = supportFormatSize / sizeof(OSType);
            OSType *supportFormats = malloc(supportFormatSize);
            status = AudioFormatGetProperty(kAudioFormatProperty_DecodeFormatIDs, 0, NULL, &supportFormatSize, supportFormats);
            if (status != noErr) {
                free(formatList);
                free(supportFormats);
                [self closeAudioFile];
                return;
            }
            for (int i = 0 ; i * sizeof(AudioFormatListItem) < formatListSize; i ++) {
                AudioStreamBasicDescription format = formatList[i].mASBD;
                for (int j = 0 ; j < formatCount; j ++) {
                    if (format.mFormatID == supportFormats[j]) {
                        _format = format;
                        found = YES;
                        break;
                    }
                }
            }
            free(supportFormats);
            
        }
        free(formatList);
        if (!found) {
            [self closeAudioFile];
            return;
        } else {
            [self getPacketDuration];
        }
        
        uint32_t bitrateSize = sizeof(_bitRate);
        status = AudioFileGetProperty(_audioFileId, kAudioFilePropertyBitRate, &bitrateSize, &_bitRate);
        if (status != noErr) {
            [self closeAudioFile];
            return;
        }
        uint32_t size = sizeof(_dataOffset);
        status = AudioFileGetProperty(_audioFileId, kAudioFilePropertyDataOffset, &size, &_dataOffset);
        if (status != noErr) {
            [self closeAudioFile];
            return;
        }
        _audioDataByteCount = _fileSize -_dataOffset;
        
        size = sizeof(_duration);
        status = AudioFileGetProperty(_audioFileId, kAudioFilePropertyEstimatedDuration, &size, &_duration);
        if (status != noErr) {
            [self getDuration];
        }
        
        size = sizeof(_maxPacketSize);
        status = AudioFileGetProperty(_audioFileId, kAudioFilePropertyPacketSizeUpperBound, &size, &_maxPacketSize);
        if (status != noErr || _maxPacketSize == 0) {
            status = AudioFileGetProperty(_audioFileId, kAudioFilePropertyMaximumPacketSize, &size, &_maxPacketSize);
            if (status != noErr) {
                [self closeAudioFile];
                return;
            }
        }
    }
}
- (void)getDuration{
    if (_fileSize > 0 && _bitRate > 0) {
        _duration = ((_fileSize - _dataOffset) * 8) / _bitRate;
    }
}
- (void)getPacketDuration{
    if (_format.mSampleRate) {
        _packetDuration = _format.mFramesPerPacket / _format.mSampleRate;
    }
}
- (void)closeAudioFile{
    if (self.available) {
        AudioFileClose(_audioFileId);
        _audioFileId = NULL;
    }
}
-(NSData *)fetchMagicCookie{
    uint32_t cookieSize ;
    OSStatus status = AudioFileGetPropertyInfo(_audioFileId, kAudioFilePropertyMagicCookieData, &cookieSize, NULL);
    if (status != noErr) {
        return nil;
    }
    void *cookieData = malloc(cookieSize);
    status = AudioFileGetProperty(_audioFileId, kAudioFilePropertyMagicCookieData, &cookieSize, cookieData);
    if (status != noErr) {
        return nil;
    }
    NSData *data = [NSData dataWithBytes:cookieData length:cookieSize];
    return data;
}
-(NSArray *)parseData:(BOOL *)stop{
    uint32_t ioNumPackets = packetPerRead;
    uint32_t ioNumBytes = ioNumPackets * _maxPacketSize;
    void *outBuffer = (void *)malloc(ioNumBytes);
    OSStatus status = noErr;
    AudioStreamPacketDescription *aspd = NULL;
    uint32_t size = sizeof(AudioStreamPacketDescription) * ioNumPackets;
    aspd = (AudioStreamPacketDescription *)malloc(size);
    status = AudioFileReadPacketData(_audioFileId, false, &ioNumBytes, aspd, _dataOffset, &ioNumPackets, outBuffer);
    if (status != noErr) {
        *stop = status == kAudioFileEndOfFileError;
        free(outBuffer);
        return nil;
    }
    if (ioNumBytes == 0) {
        *stop = YES;
    }
    _dataOffset += ioNumPackets;
    if (ioNumPackets > 0) {
        NSMutableArray *dataArray = [NSMutableArray array];
        for (int i = 0 ; i < ioNumPackets; i ++) {
            AudioStreamPacketDescription packetDecsription ;
            if (aspd) {
                packetDecsription = aspd[i];
            } else {
                packetDecsription.mStartOffset = i * _format.mBytesPerPacket;
                packetDecsription.mDataByteSize = _format.mBytesPerPacket;
                packetDecsription.mVariableFramesInPacket = _format.mFramesPerPacket;
            }
            SCXAudioData *audioData = [SCXAudioData audioDataWithBytes:outBuffer + packetDecsription.mStartOffset packetDescription:packetDecsription];
            if (audioData) {
                [dataArray addObject:audioData];
            }
        }
        return dataArray;
    }
    return nil;
}
- (uint32_t)avaiableDataLengthAtOffset:(SInt64)inPosition maxLength:(uint32_t)requestCount{
    if ((inPosition + requestCount) > _fileSize) {
        if (inPosition > _fileSize) {
            return 0;
        } else {
            return (uint32_t)(_fileSize - inPosition);
        }
    } else {
        return requestCount;
    }
}
- (NSData *)dataOffset:(SInt64)inPosition length:(uint32_t)length{
    [_fileHandle seekToFileOffset:inPosition];
    return [_fileHandle readDataOfLength:length];
}
-(void)close{
    [self closeAudioFile];
}
-(void)dealloc{
    [_fileHandle closeFile];
    [self closeAudioFile];
}
OSStatus scx_AudioFile_ReadProc(
void *        inClientData,
SInt64        inPosition,
UInt32        requestCount,
void *        buffer,
                               UInt32 *    actualCount){
    SCXAudioFile *audioFile = (__bridge SCXAudioFile *)inClientData;
    *actualCount = [audioFile avaiableDataLengthAtOffset:inPosition maxLength:requestCount];
    if (*actualCount > 0) {
        NSData *data = [audioFile dataOffset:inPosition length:*actualCount];
        memcpy(buffer, [data bytes], [data length]);
    }
    
    return noErr;
    
}
SInt64 scx_audioFile_GetSizeProc(
                             void *         inClientData){
    SCXAudioFile *audioFile = (__bridge SCXAudioFile *)inClientData;
    
    return audioFile.fileSize;
}
-(BOOL)available{
    return _audioFileId != NULL;
}
@end
