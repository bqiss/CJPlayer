//
//  ViewController.m
//  DecodeByVideoToolBox
//
//  Created by 陈剑 on 2021/12/15.
//

#import "ViewController.h"
#import "DisplayViewController.h"
#import "InputRTMPUrlViewController.h"
#import <AVFoundation/AVFoundation.h>
#define screenWidth [UIScreen mainScreen].bounds.size.width
#define screenHeight [UIScreen mainScreen].bounds.size.height
@interface ViewController ()<UITableViewDelegate, UITableViewDataSource, UINavigationControllerDelegate, UIImagePickerControllerDelegate>
@property (nonatomic, strong) UITableView * tableView;
@end

typedef enum MyFileType {
    MovePicker = 0,
    RTMPUrl,
    NetVideo,
}MyFileType;


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Main";
    self.tableView = [[UITableView alloc]initWithFrame:CGRectMake(0, 0, screenWidth, screenHeight) style:UITableViewStylePlain];
    [self.view addSubview:self.tableView];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 3;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell * cell = [[UITableViewCell alloc]initWithFrame:CGRectMake(0, 0, screenWidth, 50)];
    cell.textLabel.font = [UIFont systemFontOfSize:25];
    cell.textLabel.textColor = [UIColor blackColor];
        switch (indexPath.row) {
            case MovePicker: {
                cell.textLabel.text = @"MovePicker";
            }
                break;
            case RTMPUrl:
                cell.textLabel.text = @"TypeRTMPUrl";
                break;
            case NetVideo:
                cell.textLabel.text = @"TypeNetVideoUrl";
                break;
            default:
                break;
        }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.row) {
        case MovePicker: {
                UIImagePickerController * picker = [[UIImagePickerController alloc]init];
                picker.delegate = self;
                picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
                picker.mediaTypes = [NSArray arrayWithObjects:@"public.movie",  nil];
                [self presentViewController:picker animated:YES completion:nil];
        }
            break;
        case RTMPUrl: {
            InputRTMPUrlViewController *rtmpVc = [[InputRTMPUrlViewController alloc]init];

            UINavigationController *navigationController = [[UINavigationController alloc]initWithRootViewController:rtmpVc];
//            rtmpVc.modalPresentationStyle = UIModalPresentationFullScreen;
            [self presentViewController:navigationController animated:YES completion:^{

            }];
        }
            
            break;
        case NetVideo:
            break;
        default:
            break;
    }
}

-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info
{
    NSURL *url = [info valueForKey:UIImagePickerControllerMediaURL];

    NSString *pathString = url.relativePath;
    NSLog(@"%@",pathString);

    [self dismissViewControllerAnimated:YES completion:^{
        DisplayViewController *displayVC = [[DisplayViewController alloc]initWithUrl:url.relativePath];
        displayVC.modalPresentationStyle = UIModalPresentationFullScreen;
        UINavigationController *navigationController = [[UINavigationController alloc]initWithRootViewController:displayVC];

//        [self.navigationController pushViewController:displayVC animated:YES];
        [self presentViewController:navigationController animated:YES completion:^{

        }];

       
    }];
}
@end
