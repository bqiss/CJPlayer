//
//  ViewController.m
//  DecodeByVideoToolBox
//
//  Created by 陈剑 on 2021/12/15.
//

#import "SelectLocalVideoViewController.h"
#import "DisplayViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface SelectLocalVideoViewController ()<UINavigationControllerDelegate,UIImagePickerControllerDelegate>
@property (nonatomic, strong) UIButton *selectBtn;
@end

@implementation SelectLocalVideoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.selectBtn = [[UIButton alloc]initWithFrame:CGRectMake(100, 100, 100, 100)];
    [self.selectBtn setTitle:@"选择视频" forState:UIControlStateNormal];
    [self.selectBtn addTarget:self action:@selector(selectVideo) forControlEvents:UIControlEventTouchUpInside];
    [self.selectBtn setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [self.view addSubview:self.selectBtn];
}

- (void)selectVideo {
    UIImagePickerController * picker = [[UIImagePickerController alloc]init];
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.mediaTypes = [NSArray arrayWithObjects:@"public.movie",  nil];
    [self presentViewController:picker animated:YES completion:nil];
}

-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info
{
    NSURL *url = [info valueForKey:UIImagePickerControllerMediaURL];

    NSString *pathString = url.relativePath;
    NSLog(@"%@",pathString);

    [self dismissViewControllerAnimated:YES completion:^{
            DisplayViewController *displayVC = [[DisplayViewController alloc]init];
        displayVC.modalPresentationStyle = UIModalPresentationFullScreen;
        displayVC.url = url;
            [self presentViewController:displayVC animated:YES completion:nil];
    }];
}
@end
