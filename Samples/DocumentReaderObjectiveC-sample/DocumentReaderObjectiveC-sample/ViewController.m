//
//  ViewController.m
//  DocumentReaderObjectiveC-sample
//
//  Created by Dmitry Smolyakov on 3/19/18.
//  Copyright © 2018 Dmitry Smolyakov. All rights reserved.
//

#import "ViewController.h"
@import DocumentReader;
@import Photos;

@interface ViewController () <UIPickerViewDelegate, UIPickerViewDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

    @property (weak, nonatomic) IBOutlet UILabel *nameLabel;
    @property (weak, nonatomic) IBOutlet UIImageView *documentImage;
    @property (weak, nonatomic) IBOutlet UIImageView *portraitImageView;
    @property (weak, nonatomic) IBOutlet UIPickerView *pickerView;
    @property (weak, nonatomic) IBOutlet UIButton *userRecognizeImage;
    @property (weak, nonatomic) IBOutlet UIButton *useCameraViewControllerButton;

    @property (weak, nonatomic) IBOutlet UILabel *initializationLabel;
    @property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

    @property (strong, nonatomic) UIImagePickerController *imagePicker;

    @property (weak, nonatomic) IBOutlet UISwitch *rfidCheckBox;

@end

@implementation ViewController

    - (void)viewDidLoad {
        [super viewDidLoad];
        [self initializationReader];
        self.imagePicker = [[UIImagePickerController alloc] init];
        // Do any additional setup after loading the view, typically from a nib.
    }

    - (void)initializationReader {
        //initialize license
        NSString *dataPath = [[NSBundle mainBundle] pathForResource:@"regula.license" ofType:nil];
        NSData *licenseData = [NSData dataWithContentsOfFile:dataPath];
        
        [RGLDocReader.shared prepareDatabase:@"FullAuth" progressHandler:^(NSProgress * _Nonnull progress) {
            self.initializationLabel.text = [NSString stringWithFormat:@"%.1f", progress.fractionCompleted * 100];
        } completion:^(BOOL successful, NSString * _Nullable error) {
            if (successful) {
                self.initializationLabel.text = @"Initialization...";
                [RGLDocReader.shared initializeReader:licenseData completion:^(BOOL successful, NSString * _Nullable error ) {
                    if (successful) {
                        [self.activityIndicator stopAnimating];
                        [self.initializationLabel setHidden:YES];
                        [self.userRecognizeImage setHidden:NO];
                        [self.useCameraViewControllerButton setHidden:NO];
                        [self.pickerView setHidden:NO];
                        [self.pickerView reloadAllComponents];
                        [self.pickerView selectRow:0 inComponent:0 animated:NO];

                        RGLScenario *scenario = [RGLDocReader shared].availableScenarios.firstObject;
                        if (scenario) {
                            [RGLDocReader shared].processParams.scenario = scenario.identifier;
                        }
                        [RGLDocReader shared].functionality.singleResult = YES;
                        
                        if (RGLDocReader.shared.isUseAuthenticatorAvailable) {
                            RGLDocReader.shared.functionality.useAuthenticator = YES;
                            RGLDocReader.shared.functionality.btDeviceName = @"Regula 0000"; // set up name of the 1120 device
                        }
                        
                        for (RGLScenario *scenario in RGLDocReader.shared.availableScenarios) {
                            NSLog(@"%@", scenario);
                            NSLog(@"---------");
                        }
                    } else {
                        [self.activityIndicator stopAnimating];
                        self.initializationLabel.text = [NSString stringWithFormat:@"Initialization error: %@", error];
                        NSLog(@"%@", error);
                    }
                }];
            } else {
                self.initializationLabel.text = [NSString stringWithFormat:@"Downloading database error: %@", error];
                NSLog(@"%@", error);
            }
        }];
    }

    - (IBAction)useCameraViewController:(UIButton *)sender {
        [RGLDocReader.shared showScanner:self completion:^(enum RGLDocReaderAction action, RGLDocumentReaderResults * _Nullable result, NSString * _Nullable error) {
            switch (action) {
                case RGLDocReaderActionCancel: {
                    NSLog(@"Cancelled by user");
                }
                break;

                case RGLDocReaderActionComplete: {
                    NSLog(@"Completed");
                    if (self.rfidCheckBox.on) {
                        [self startRFIDReading:result];
                    } else {
                        [self handleScanResults:result];
                    }
                }
                break;

                case RGLDocReaderActionError: {
                    NSLog(@"Error string: %@", error);
                }
                break;

                case RGLDocReaderActionProcess: {
                    NSLog(@"Scaning not finished. Result: %@", result);
                }
                break;

                default:
                break;
            }
        }];
    }

    - (IBAction)useRecognizeImageMethod:(UIButton *)sender {
        [self getImageFromGallery];
    }

    - (void)getImageFromGallery {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            switch (status) {
                case PHAuthorizationStatusAuthorized: {
                    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeSavedPhotosAlbum]) {
                        self.imagePicker.delegate = self;
                        self.imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
                        self.imagePicker.allowsEditing = NO;
                        dispatch_async(dispatch_get_main_queue(), ^{
                            self.imagePicker.navigationBar.tintColor = [UIColor blackColor];
                            [self presentViewController:self.imagePicker animated:YES completion:nil];
                        });
                    }
                }
                break;

                case PHAuthorizationStatusDenied: {
                    NSString *message = @"Application doesn't have permission to use the camera, please change privacy settings";
                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Gallery Unavailable" message:message preferredStyle:UIAlertControllerStyleAlert];
                    [alertController addAction: [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                    [alertController addAction:[UIAlertAction actionWithTitle:@"Settings" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        [UIApplication.sharedApplication openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
                    }]];
                    [self presentViewController:alertController animated:YES completion:nil];
                }
                break;

                case PHAuthorizationStatusNotDetermined: {
                    NSLog(@"%@", @"PHPhotoLibrary status: notDetermined");
                }

                case PHAuthorizationStatusRestricted: {
                    NSLog(@"%@", @"PHPhotoLibrary status: restricted");
                }

                default:
                break;
            }
        }];
    }

    - (void)handleScanResults:(RGLDocumentReaderResults *)result {
        // use fast getValue method
        NSString *name = [result getTextFieldValueByType:RGLFieldTypeFt_Surname_And_Given_Names];
        NSLog(@"%@", name);
        self.nameLabel.text = name;
        UIImage *uvDocImage = [result getGraphicFieldImageByType:RGLGraphicFieldTypeGf_DocumentImage source:RGLResultTypeRawImage pageIndex:0 light:RGLGraphicFieldLightUV];
        if (uvDocImage) {
            self.documentImage.image = uvDocImage;
        } else {
            self.documentImage.image = [result getGraphicFieldImageByType:RGLGraphicFieldTypeGf_DocumentImage source:RGLResultTypeRawImage];
        }
        self.portraitImageView.image = [result getGraphicFieldImageByType:RGLGraphicFieldTypeGf_Portrait];

        for (RGLDocumentReaderTextField *textField in result.textResult.fields) {
            NSString *value = [result getTextFieldValueByType:textField.fieldType lcid:textField.lcid];
            NSLog(@"Field type name: %@, value: %@", textField.fieldName, value);
        }
    }

    - (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
        UIImage *image = info[UIImagePickerControllerOriginalImage];
        [self dismissViewControllerAnimated:YES completion:^{

            [RGLDocReader.shared recognizeImage:image cameraMode:NO completion:^(RGLDocReaderAction action, RGLDocumentReaderResults * _Nullable results, NSString * _Nullable error) {
                if (action == RGLDocReaderActionComplete) {
                    if (results != nil) {
                        NSLog(@"Completed");
                        [self handleScanResults:results];
                    }
                } else if (action == RGLDocReaderActionError) {
                    [self dismissViewControllerAnimated:YES completion:nil];
                    NSLog(@"Something went wrong");
                }
            }];
        }];
    }

    - (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
        return 1;
    }

    - (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
        return RGLDocReader.shared.availableScenarios.count;
    }


    - (nullable NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
        return RGLDocReader.shared.availableScenarios[row].identifier;
    }

    - (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
        RGLDocReader.shared.processParams.scenario = RGLDocReader.shared.availableScenarios[row].identifier;
    }

    - (void)startRFIDReading:(RGLDocumentReaderResults *)result {
        NSString *mrzAccessKey = [[result getTextFieldValueByType:RGLFieldTypeFt_MRZ_Strings_ICAO_RFID] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        if (mrzAccessKey) {
            RGLDocReader.shared.processParams.rfidOptions.mrz = mrzAccessKey;
            RGLDocReader.shared.processParams.rfidOptions.pacePasswordType = RGLRFIDPasswordTypeMrz;
            RGLDocReader.shared.processParams.rfidOptions.readEDL = [mrzAccessKey length] == 30 && [mrzAccessKey characterAtIndex:0] == 'D';
        }
        NSString *stringAccessKey = [[result getTextFieldValueByType:RGLFieldTypeFt_MRZ_Strings] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        if (stringAccessKey) {
            RGLDocReader.shared.processParams.rfidOptions.mrz = stringAccessKey;
            RGLDocReader.shared.processParams.rfidOptions.pacePasswordType = RGLRFIDPasswordTypeMrz;
            RGLDocReader.shared.processParams.rfidOptions.readEDL = [stringAccessKey length] == 30 && [stringAccessKey characterAtIndex:0] == 'D';
        }
        NSString *accessNumberKey = [result getTextFieldValueByType:RGLFieldTypeFt_Card_Access_Number];
        if (accessNumberKey) {
            RGLDocReader.shared.processParams.rfidOptions.mrz = accessNumberKey;
            RGLDocReader.shared.processParams.rfidOptions.pacePasswordType = RGLRFIDPasswordTypeCan;
            RGLDocReader.shared.processParams.rfidOptions.readEDL = [accessNumberKey length] == 30 && [accessNumberKey characterAtIndex:0] == 'D';
        }
        
        [RGLDocReader.shared startRFIDReaderFromPresenter:self completion:^(enum RGLDocReaderAction action, RGLDocumentReaderResults * _Nullable results, NSString * _Nullable error) {
            switch (action) {
                case RGLDocReaderActionCancel: {
                    NSLog(@"Cancelled by user");
                    [self handleScanResults:result];
                }
                    break;
                    
                case RGLDocReaderActionComplete: {
                    NSLog(@"Completed");
                    [self handleScanResults:results];
                }
                    break;
                    
                case RGLDocReaderActionError: {
                    NSLog(@"Error string: %@", error);
                }
                    break;
                    
                default:
                    break;
            }
        }];
    }
@end
