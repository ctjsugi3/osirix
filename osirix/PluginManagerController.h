//
//  PluginManagerController.h
//  OsiriX
//
//  Created by joris on 26/02/07.
//  Copyright 2007 OsiriX Team. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "PluginManager.h"

@interface PluginManagerController : NSWindowController {

    IBOutlet NSMenu	*filtersMenu;
	IBOutlet NSMenu	*roisMenu;
	IBOutlet NSMenu	*othersMenu;
	IBOutlet NSMenu	*dbMenu;

	NSMutableArray* plugins;
	IBOutlet NSTableView *pluginTable;
	
	IBOutlet NSTabView *tabView;
	
	IBOutlet WebView *webView;
	NSArray *pluginsListURLs;
	IBOutlet NSPopUpButton *pluginsListPopUp;
	NSString *downloadURL, *downloadedFilePath;
	IBOutlet NSButton *downloadButton;
	IBOutlet NSTextField *statusTextField;
	IBOutlet NSProgressIndicator *statusProgressIndicator;
}

- (NSMutableArray*)plugins;
- (IBAction)modifiy:(id)sender;
- (IBAction)delete:(id)sender;
- (void)loadPlugins;
- (IBAction)loadPlugins:(id)sender;

- (NSArray*)availablePlugins;
- (void)generateAvailablePluginsMenu;
- (void)setURL:(NSString*)url;
- (IBAction)changeWebView:(id)sender;
- (void)setURLforPluginWithName:(NSString*)name;

- (void)setDownloadURL:(NSString*)url;
- (IBAction)download:(id)sender;

- (void)installDownloadedPluginAtPath:(NSString*)path;
- (BOOL)isZippedFileAtPath:(NSString*)path;
- (BOOL)unZipFileAtPath:(NSString*)path;

@end
