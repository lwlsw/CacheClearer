#import <dlfcn.h>
#import <objc/runtime.h>
#import <substrate.h>

@interface PSSpecifier : NSObject
+ (instancetype)deleteButtonSpecifierWithName:(NSString *)name target:(id)target action:(SEL)action;
- (void)setProperty:(id)value forKey:(NSString *)key;
- (id)propertyForKey:(NSString *)key;
- (void)setConfirmationAction:(SEL)action;
@property (nonatomic, readonly) NSString *identifier;
+ (id)emptyGroupSpecifier;
@end

@interface PSViewController : UIViewController {
@public
	PSSpecifier *_specifier;
}
@end

@interface PSListController : PSViewController {
@public
	NSMutableArray *_specifiers;
}
- (NSArray *)specifiers;
- (void)showConfirmationViewForSpecifier:(PSSpecifier *)specifier;
@end

@interface UsageDetailController : PSListController
- (BOOL)isAppController;
@end

@interface LSBundleProxy : NSObject
@property (nonatomic, readonly) NSURL *dataContainerURL;
@end

@interface LSApplicationProxy : LSBundleProxy
+ (instancetype)applicationProxyForIdentifier:(NSString *)identifier;
@property (nonatomic, readonly) NSString *localizedShortName;
@property (nonatomic, readonly) NSString *itemName;
@property (nonatomic, readonly) NSNumber *dynamicDiskUsage;
@end

typedef const struct __SBSApplicationTerminationAssertion *SBSApplicationTerminationAssertionRef;

extern "C" SBSApplicationTerminationAssertionRef SBSApplicationTerminationAssertionCreateWithError(void *unknown, NSString *bundleIdentifier, int reason, int *outError);
extern "C" void SBSApplicationTerminationAssertionInvalidate(SBSApplicationTerminationAssertionRef assertion);
extern "C" NSString *SBSApplicationTerminationAssertionErrorString(int error);

#define NSLog(...)


@interface PSStorageApp : NSObject
@property (nonatomic,readonly) NSString * appIdentifier;
@property (nonatomic,readonly) LSApplicationProxy * appProxy;
@end

@interface STStorageAppDetailController : PSListController
{
	PSStorageApp* _storageApp;
}
@end

%hook STStorageAppDetailController
- (NSArray*)specifiers
{
	NSArray* ret = %orig;
	NSMutableArray* _specifiers = [ret mutableCopy];
		PSSpecifier* specifier;
		specifier = [PSSpecifier emptyGroupSpecifier];
        [_specifiers addObject:specifier];
		
		specifier = [PSSpecifier deleteButtonSpecifierWithName:@"重置App" target:self action:@selector(resetDiskContent)];
		[specifier setConfirmationAction:@selector(clearCaches)];
		[_specifiers addObject:specifier];
		specifier = [PSSpecifier deleteButtonSpecifierWithName:@"清空App的缓存" target:self action:@selector(clearCaches)];
		[specifier setConfirmationAction:@selector(clearCaches)];
		[_specifiers addObject:specifier];
		
		ret = [_specifiers copy];
		MSHookIvar<NSArray*>(self, "_specifiers") = ret;
	return ret;
}


static void ClearDirectoryURLContents(NSURL *url)
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSDirectoryEnumerator *enumerator = [fm enumeratorAtURL:url includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsSubdirectoryDescendants errorHandler:nil];
	NSURL *child;
	while ((child = [enumerator nextObject])) {
		[fm removeItemAtURL:child error:NULL];
	}
}

static UIViewController* topMostController() {
    UIViewController *topController = [UIApplication sharedApplication].windows[0].rootViewController;
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    
    return topController;
}

static void ShowMessage(NSString *message)
{
	NSLog(@"清理---");
	UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"CacheClearer" message:message preferredStyle:UIAlertControllerStyleAlert];

	[alertController addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    
	[topMostController() presentViewController:alertController animated:YES completion:nil];

	// UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"CacheClearer" message:message delegate:nil cancelButtonTitle:@"好的" otherButtonTitles:nil];
	// [alertController show];
	// [alertController release];
}

%new
- (void)resetDiskContent
{
	PSStorageApp* _storageApp = MSHookIvar<PSStorageApp*>(self, "_storageApp");	
	NSString *identifier = _storageApp.appIdentifier;
	LSApplicationProxy *app = [LSApplicationProxy applicationProxyForIdentifier:identifier];
	NSString *title = app.localizedShortName;
	NSNumber *originalDynamicSize = [[app.dynamicDiskUsage retain] autorelease];
	NSURL *dataContainer = app.dataContainerURL;
	SBSApplicationTerminationAssertionRef assertion = SBSApplicationTerminationAssertionCreateWithError(NULL, identifier, 1, NULL);
	ClearDirectoryURLContents([dataContainer URLByAppendingPathComponent:@"tmp" isDirectory:YES]);
	NSURL *libraryURL = [dataContainer URLByAppendingPathComponent:@"Library" isDirectory:YES];
	ClearDirectoryURLContents(libraryURL);
	[[NSFileManager defaultManager] createDirectoryAtURL:[libraryURL URLByAppendingPathComponent:@"Preferences" isDirectory:YES] withIntermediateDirectories:YES attributes:nil error:NULL];
	ClearDirectoryURLContents([dataContainer URLByAppendingPathComponent:@"Documents" isDirectory:YES]);
	if (assertion) {
		SBSApplicationTerminationAssertionInvalidate(assertion);
	}
	NSNumber *newDynamicSize = [LSApplicationProxy applicationProxyForIdentifier:identifier].dynamicDiskUsage;
	if ([newDynamicSize isEqualToNumber:originalDynamicSize]) {
		ShowMessage([NSString stringWithFormat:@"%@ 已经被重置过，无须再重置。", title]);
	} else {
		ShowMessage([NSString stringWithFormat:@"%@ 重置成功！被清理出 %d M!", title, [[NSNumber numberWithDouble:[originalDynamicSize doubleValue] - [newDynamicSize doubleValue]] intValue]/1024/1024]);
	}
}

%new
- (void)clearCaches
{
	PSStorageApp* _storageApp = MSHookIvar<PSStorageApp*>(self, "_storageApp");	
	NSString *identifier = _storageApp.appIdentifier;
	LSApplicationProxy *app = [LSApplicationProxy applicationProxyForIdentifier:identifier];
	NSString *title = app.localizedShortName;
	NSNumber *originalDynamicSize = [[app.dynamicDiskUsage retain] autorelease];
	NSURL *dataContainer = app.dataContainerURL;
	SBSApplicationTerminationAssertionRef assertion = SBSApplicationTerminationAssertionCreateWithError(NULL, identifier, 1, NULL);
	ClearDirectoryURLContents([dataContainer URLByAppendingPathComponent:@"tmp" isDirectory:YES]);
	ClearDirectoryURLContents([[dataContainer URLByAppendingPathComponent:@"Library" isDirectory:YES] URLByAppendingPathComponent:@"Caches" isDirectory:YES]);
	ClearDirectoryURLContents([[[dataContainer URLByAppendingPathComponent:@"Library" isDirectory:YES] URLByAppendingPathComponent:@"Application Support" isDirectory:YES] URLByAppendingPathComponent:@"Dropbox" isDirectory:YES]);
	if (assertion) {
		SBSApplicationTerminationAssertionInvalidate(assertion);
	}
	NSNumber *newDynamicSize = [LSApplicationProxy applicationProxyForIdentifier:identifier].dynamicDiskUsage;
	if ([newDynamicSize isEqualToNumber:originalDynamicSize]) {
		ShowMessage([NSString stringWithFormat:@"%@ 的缓存已被清理过，无须在进行清理。", title]);
	} else {
		ShowMessage([NSString stringWithFormat:@"清理出 %d M的缓存!\n%@ 下次启动可能会很慢。", [[NSNumber numberWithDouble:[originalDynamicSize doubleValue] - [newDynamicSize doubleValue]] intValue]/1024/1024, title]);
	}
}

%end


%ctor
{
	dlopen("/System/Library/PreferenceBundles/StorageSettings.bundle/StorageSettings", RTLD_LAZY);
}