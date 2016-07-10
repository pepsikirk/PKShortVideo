//
//  PKMessageViewController.m
//  PKShortVideo
//
//  Created by pepsikirk on 16/1/2.
//  Copyright © 2016年 pepsikirk. All rights reserved.
//

#import "PKMessageViewController.h"
#import "PKDemoModelData.h"
#import "PKRecordShortVideoViewController.h"
#import "PKShortVideoItem.h"
#import "PKFullScreenPlayerViewController.h"
#import "UIImage+PKShortVideoPlayer.h"

@interface PKMessageViewController () <UIActionSheetDelegate, PKRecordShortVideoDelegate>

@property (strong, nonatomic) PKDemoModelData *demoData;

@end

@implementation PKMessageViewController

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"PKMessages";
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage jsq_defaultTypingIndicatorImage]
                                                                              style:UIBarButtonItemStyleDone
                                                                             target:self
                                                                             action:@selector(receiveMessagePressed:)];
    
    self.demoData = [[PKDemoModelData alloc] init];
}




#pragma mark - Actions

- (void)receiveMessagePressed:(UIBarButtonItem *)sender {
    /**
     *  DEMO ONLY
     *
     *  The following is simply to simulate received messages for the demo.
     *  Do not actually do this.
     */
    
    
    /**
     *  Show the typing indicator to be shown
     */
    self.showTypingIndicator = !self.showTypingIndicator;
    
    /**
     *  Scroll to actually view the indicator
     */
    [self scrollToBottomAnimated:YES];
    
    /**
     *  Copy last sent message, this will be the new "received" message
     */
    JSQMessage *copyMessage = [[self.demoData.messages lastObject] copy];
    
    if (!copyMessage) {
        copyMessage = [JSQMessage messageWithSenderId:kJSQDemoAvatarIdJobs
                                          displayName:kJSQDemoAvatarDisplayNameJobs
                                                 text:@"First received!"];
    }
        
    NSMutableArray *userIds = [[self.demoData.users allKeys] mutableCopy];
    [userIds removeObject:self.senderId];
    NSString *randomUserId = userIds[arc4random_uniform((int)[userIds count])];
    
    JSQMessage *newMessage = nil;
    id<JSQMessageMediaData> newMediaData = nil;
    id newMediaAttachmentCopy = nil;
    
    if (copyMessage.isMediaMessage) {
        /**
         *  Last message was a media message
         */
        id<JSQMessageMediaData> copyMediaData = copyMessage.media;
        
        if ([copyMediaData isKindOfClass:[JSQPhotoMediaItem class]]) {
            JSQPhotoMediaItem *photoItemCopy = [((JSQPhotoMediaItem *)copyMediaData) copy];
            photoItemCopy.appliesMediaViewMaskAsOutgoing = NO;
            newMediaAttachmentCopy = [UIImage imageWithCGImage:photoItemCopy.image.CGImage];
            
            /**
             *  Set image to nil to simulate "downloading" the image
             *  and show the placeholder view
             */
            photoItemCopy.image = nil;
            
            newMediaData = photoItemCopy;
        }
        else if ([copyMediaData isKindOfClass:[JSQLocationMediaItem class]]) {
            JSQLocationMediaItem *locationItemCopy = [((JSQLocationMediaItem *)copyMediaData) copy];
            locationItemCopy.appliesMediaViewMaskAsOutgoing = NO;
            newMediaAttachmentCopy = [locationItemCopy.location copy];
            
            /**
             *  Set location to nil to simulate "downloading" the location data
             */
            locationItemCopy.location = nil;
            
            newMediaData = locationItemCopy;
        }
        else if ([copyMediaData isKindOfClass:[JSQVideoMediaItem class]]) {
            JSQVideoMediaItem *videoItemCopy = [((JSQVideoMediaItem *)copyMediaData) copy];
            videoItemCopy.appliesMediaViewMaskAsOutgoing = NO;
            newMediaAttachmentCopy = [videoItemCopy.fileURL copy];
            
            /**
             *  Reset video item to simulate "downloading" the video
             */
            videoItemCopy.fileURL = nil;
            videoItemCopy.isReadyToPlay = NO;
            
            newMediaData = videoItemCopy;
        }
        else if ([copyMediaData isKindOfClass:[JSQAudioMediaItem class]]) {
            JSQAudioMediaItem *audioItemCopy = [((JSQAudioMediaItem *)copyMediaData) copy];
            audioItemCopy.appliesMediaViewMaskAsOutgoing = NO;
            newMediaAttachmentCopy = [audioItemCopy.audioData copy];
            
            /**
             *  Reset audio item to simulate "downloading" the audio
             */
            audioItemCopy.audioData = nil;
            
            newMediaData = audioItemCopy;
        }
        else if ([copyMediaData isKindOfClass:[PKShortVideoItem class]]) {
            PKShortVideoItem *videoItemCopy = [((PKShortVideoItem *)copyMediaData) copy];
            videoItemCopy.appliesMediaViewMaskAsOutgoing = NO;
            newMediaData = videoItemCopy;
        }
        else {
            NSLog(@"%s error: unrecognized media item", __PRETTY_FUNCTION__);
        }
        
        newMessage = [JSQMessage messageWithSenderId:randomUserId
                                         displayName:self.demoData.users[randomUserId]
                                               media:newMediaData];
    }
    else {
        /**
         *  Last message was a text message
         */
        newMessage = [JSQMessage messageWithSenderId:randomUserId
                                         displayName:self.demoData.users[randomUserId]
                                                text:copyMessage.text];
    }
    
    /**
     *  Upon receiving a message, you should:
     *
     *  1. Play sound (optional)
     *  2. Add new id<JSQMessageData> object to your data source
     *  3. Call `finishReceivingMessage`
     */
    
    // [JSQSystemSoundPlayer jsq_playMessageReceivedSound];
    
    [self.demoData.messages addObject:newMessage];
    [self finishReceivingMessageAnimated:YES];
    
    
    if (newMessage.isMediaMessage) {
        /**
         *  Simulate "downloading" media
         */
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            /**
             *  Media is "finished downloading", re-display visible cells
             *
             *  If media cell is not visible, the next time it is dequeued the view controller will display its new attachment data
             *
             *  Reload the specific item, or simply call `reloadData`
             */
            
            if ([newMediaData isKindOfClass:[JSQPhotoMediaItem class]]) {
                ((JSQPhotoMediaItem *)newMediaData).image = newMediaAttachmentCopy;
                [self.collectionView reloadData];
            }
            else if ([newMediaData isKindOfClass:[JSQLocationMediaItem class]]) {
                [((JSQLocationMediaItem *)newMediaData)setLocation:newMediaAttachmentCopy withCompletionHandler:^{
                    [self.collectionView reloadData];
                }];
            }
            else if ([newMediaData isKindOfClass:[JSQVideoMediaItem class]]) {
                ((JSQVideoMediaItem *)newMediaData).fileURL = newMediaAttachmentCopy;
                ((JSQVideoMediaItem *)newMediaData).isReadyToPlay = YES;
                [self.collectionView reloadData];
            }
            else if ([newMediaData isKindOfClass:[JSQAudioMediaItem class]]) {
                ((JSQAudioMediaItem *)newMediaData).audioData = newMediaAttachmentCopy;
                [self.collectionView reloadData];
            }
            else if ([newMediaData isKindOfClass:[PKShortVideoItem class]]) {
                
            }
            else {
                NSLog(@"%s error: unrecognized media item", __PRETTY_FUNCTION__);
            }
            
        });
    }
}



#pragma mark - JSQMessagesViewController method overrides

- (void)didPressSendButton:(UIButton *)button
           withMessageText:(NSString *)text
                  senderId:(NSString *)senderId
         senderDisplayName:(NSString *)senderDisplayName
                      date:(NSDate *)date
{
    /**
     *  Sending a message. Your implementation of this method should do *at least* the following:
     *
     *  1. Play sound (optional)
     *  2. Add new id<JSQMessageData> object to your data source
     *  3. Call `finishSendingMessage`
     */
    
    JSQMessage *message = [[JSQMessage alloc] initWithSenderId:senderId
                                             senderDisplayName:senderDisplayName
                                                          date:date
                                                          text:text];
    
    [self.demoData.messages addObject:message];
    
    [self finishSendingMessageAnimated:YES];
}

- (void)didPressAccessoryButton:(UIButton *)sender {
    [self.inputToolbar.contentView.textView resignFirstResponder];
    
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Media messages"
                                                       delegate:self
                                              cancelButtonTitle:@"Cancel"
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:@"Record short video", nil];
    
    [sheet showFromToolbar:self.inputToolbar];
}



#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) {
        [self.inputToolbar.contentView.textView becomeFirstResponder];
        return;
    }
    
    switch (buttonIndex) {
        case 0: {
            
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *fileName = [NSProcessInfo processInfo].globallyUniqueString;
            NSString *path = [paths[0] stringByAppendingPathComponent:[fileName stringByAppendingPathExtension:@"mp4"]];
            //跳转默认录制视频ViewController
            PKRecordShortVideoViewController *viewController = [[PKRecordShortVideoViewController alloc] initWithOutputFilePath:path outputSize:CGSizeMake(320, 240) themeColor:[UIColor colorWithRed:0/255.0 green:153/255.0 blue:255/255.0 alpha:1]];
            //通过代理回调
            viewController.delegate = self;
            [self presentViewController:viewController animated:YES completion:nil];
        }
            
            break;
    }
}



#pragma mark - JSQMessages CollectionView DataSource

- (NSString *)senderId {
    return kJSQDemoAvatarIdSquires;
}

- (NSString *)senderDisplayName {
    return kJSQDemoAvatarDisplayNameSquires;
}


- (id<JSQMessageData>)collectionView:(JSQMessagesCollectionView *)collectionView messageDataForItemAtIndexPath:(NSIndexPath *)indexPath {
    return [self.demoData.messages objectAtIndex:indexPath.item];
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView didDeleteMessageAtIndexPath:(NSIndexPath *)indexPath {
    [self.demoData.messages removeObjectAtIndex:indexPath.item];
}

- (id<JSQMessageBubbleImageDataSource>)collectionView:(JSQMessagesCollectionView *)collectionView messageBubbleImageDataForItemAtIndexPath:(NSIndexPath *)indexPath {
    /**
     *  You may return nil here if you do not want bubbles.
     *  In this case, you should set the background color of your collection view cell's textView.
     *
     *  Otherwise, return your previously created bubble image data objects.
     */
    
    JSQMessage *message = [self.demoData.messages objectAtIndex:indexPath.item];
    
    if ([message.senderId isEqualToString:self.senderId]) {
        return self.demoData.outgoingBubbleImageData;
    }
    
    return self.demoData.incomingBubbleImageData;
}

- (id<JSQMessageAvatarImageDataSource>)collectionView:(JSQMessagesCollectionView *)collectionView avatarImageDataForItemAtIndexPath:(NSIndexPath *)indexPath {
    /**
     *  Return `nil` here if you do not want avatars.
     *  If you do return `nil`, be sure to do the following in `viewDidLoad`:
     *
     *  self.collectionView.collectionViewLayout.incomingAvatarViewSize = CGSizeZero;
     *  self.collectionView.collectionViewLayout.outgoingAvatarViewSize = CGSizeZero;
     *
     *  It is possible to have only outgoing avatars or only incoming avatars, too.
     */
    
    /**
     *  Return your previously created avatar image data objects.
     *
     *  Note: these the avatars will be sized according to these values:
     *
     *  self.collectionView.collectionViewLayout.incomingAvatarViewSize
     *  self.collectionView.collectionViewLayout.outgoingAvatarViewSize
     *
     *  Override the defaults in `viewDidLoad`
     */
    JSQMessage *message = [self.demoData.messages objectAtIndex:indexPath.item];

    return [self.demoData.avatars objectForKey:message.senderId];
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath {
    /**
     *  This logic should be consistent with what you return from `heightForCellTopLabelAtIndexPath:`
     *  The other label text delegate methods should follow a similar pattern.
     *
     *  Show a timestamp for every 3rd message
     */
    if (indexPath.item % 3 == 0) {
        JSQMessage *message = [self.demoData.messages objectAtIndex:indexPath.item];
        return [[JSQMessagesTimestampFormatter sharedFormatter] attributedTimestampForDate:message.date];
    }
    
    return nil;
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForMessageBubbleTopLabelAtIndexPath:(NSIndexPath *)indexPath {
    JSQMessage *message = [self.demoData.messages objectAtIndex:indexPath.item];
    
    /**
     *  iOS7-style sender name labels
     */
    if ([message.senderId isEqualToString:self.senderId]) {
        return nil;
    }
    
    if (indexPath.item - 1 > 0) {
        JSQMessage *previousMessage = [self.demoData.messages objectAtIndex:indexPath.item - 1];
        if ([[previousMessage senderId] isEqualToString:message.senderId]) {
            return nil;
        }
    }
    
    /**
     *  Don't specify attributes to use the defaults.
     */
    return [[NSAttributedString alloc] initWithString:message.senderDisplayName];
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForCellBottomLabelAtIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

#pragma mark - UICollectionView DataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [self.demoData.messages count];
}

- (UICollectionViewCell *)collectionView:(JSQMessagesCollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    /**
     *  Override point for customizing cells
     */
    JSQMessagesCollectionViewCell *cell = (JSQMessagesCollectionViewCell *)[super collectionView:collectionView cellForItemAtIndexPath:indexPath];
    
    /**
     *  Configure almost *anything* on the cell
     *
     *  Text colors, label text, label colors, etc.
     *
     *
     *  DO NOT set `cell.textView.font` !
     *  Instead, you need to set `self.collectionView.collectionViewLayout.messageBubbleFont` to the font you want in `viewDidLoad`
     *
     *
     *  DO NOT manipulate cell layout information!
     *  Instead, override the properties you want on `self.collectionView.collectionViewLayout` from `viewDidLoad`
     */
    
    JSQMessage *msg = [self.demoData.messages objectAtIndex:indexPath.item];
    
    if (!msg.isMediaMessage) {
        
        if ([msg.senderId isEqualToString:self.senderId]) {
            cell.textView.textColor = [UIColor blackColor];
        }
        else {
            cell.textView.textColor = [UIColor whiteColor];
        }
        
        cell.textView.linkTextAttributes = @{ NSForegroundColorAttributeName : cell.textView.textColor,
                                              NSUnderlineStyleAttributeName : @(NSUnderlineStyleSingle | NSUnderlinePatternSolid) };
    }
    
    return cell;
}

//将要结束显示时停止播放
- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    JSQMessage *message = self.demoData.messages[indexPath.item];
    if ([message.media isKindOfClass:[PKShortVideoItem class]]) {
        PKShortVideoItem *item = (PKShortVideoItem *)message.media;
        [item pause];
    }
}

//将要显示时播放
- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    JSQMessage *message = self.demoData.messages[indexPath.item];
    if ([message.media isKindOfClass:[PKShortVideoItem class]]) {
        PKShortVideoItem *item = (PKShortVideoItem *)message.media;
        [item play];
    }
}

#pragma mark - Adjusting cell label heights

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath {

    if (indexPath.item % 3 == 0) {
        return kJSQMessagesCollectionViewCellLabelHeightDefault;
    }
    
    return 0.0f;
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForMessageBubbleTopLabelAtIndexPath:(NSIndexPath *)indexPath {
    JSQMessage *currentMessage = [self.demoData.messages objectAtIndex:indexPath.item];
    if ([[currentMessage senderId] isEqualToString:self.senderId]) {
        return 0.0f;
    }
    
    if (indexPath.item - 1 > 0) {
        JSQMessage *previousMessage = [self.demoData.messages objectAtIndex:indexPath.item - 1];
        if ([[previousMessage senderId] isEqualToString:[currentMessage senderId]]) {
            return 0.0f;
        }
    }
    
    return kJSQMessagesCollectionViewCellLabelHeightDefault;
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellBottomLabelAtIndexPath:(NSIndexPath *)indexPath {
    return 0.0f;
}

#pragma mark - Responding to collection view tap events

- (void)collectionView:(JSQMessagesCollectionView *)collectionView
                header:(JSQMessagesLoadEarlierHeaderView *)headerView didTapLoadEarlierMessagesButton:(UIButton *)sender {
    NSLog(@"Load earlier messages!");
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView didTapAvatarImageView:(UIImageView *)avatarImageView atIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"Tapped avatar!");
}

//点击消息是跳转播放
- (void)collectionView:(JSQMessagesCollectionView *)collectionView didTapMessageBubbleAtIndexPath:(NSIndexPath *)indexPath {
    JSQMessage *message = self.demoData.messages[indexPath.item];
    //判断媒体消息类型
    if ([message.media isKindOfClass:[PKShortVideoItem class]]) {
        PKShortVideoItem *item = (PKShortVideoItem *)message.media;
        //跳转全屏播放小视频界面
        PKFullScreenPlayerViewController *viewController = [[PKFullScreenPlayerViewController alloc] initWithVideoPath:item.videoPath previewImage:[UIImage pk_previewImageWithVideoURL:[NSURL fileURLWithPath:item.videoPath]]];
        [self presentViewController:viewController animated:NO completion:NULL];
    }
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView didTapCellAtIndexPath:(NSIndexPath *)indexPath touchLocation:(CGPoint)touchLocation {
    NSLog(@"Tapped cell at %@!", NSStringFromCGPoint(touchLocation));
}


#pragma mark - PKRecordShortVideoDelegate
//视频拍摄完成输出图片
- (void)didFinishRecordingToOutputFilePath:(NSString *)outputFilePath {
    //自定义的生成小视频聊天对象方法
    [self.demoData addShortVideoMediaMessageWithVideoPath:outputFilePath];
    //JSQMessagesViewController的完成发送滚动到底端方法
    [self finishSendingMessageAnimated:YES];
}

@end
