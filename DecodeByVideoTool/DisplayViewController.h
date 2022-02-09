//
//  DisplayViewController.h
//  DecodeByVideoToolBox
//
//  Created by 陈剑 on 2021/12/15.
//

#import <UIKit/UIKit.h>


NS_ASSUME_NONNULL_BEGIN

@interface DisplayViewController : UIViewController
@property (nonatomic, copy) NSURL *url;
- (instancetype)initWithUrl:(NSString *)urlStr;
@end

NS_ASSUME_NONNULL_END
