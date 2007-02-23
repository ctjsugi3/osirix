/*=========================================================================
  Program:   OsiriX

  Copyright (c) OsiriX Team
  All rights reserved.
  Distributed under GNU - GPL
  
  See http://homepage.mac.com/rossetantoine/osirix/copyright.html for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.
=========================================================================*/


#import "PluginManager.h"
#import "ViewerController.h"

#import "browserController.h"
extern BrowserController *browserWindow;

NSMutableDictionary		*plugins = 0L, *pluginsDict = 0L, *fileFormatPlugins = 0L;
NSMutableDictionary		*reportPlugins = 0L;

NSMutableArray			*preProcessPlugins = 0L;
NSMenu					*fusionPluginsMenu = 0L;
PluginManager			*pluginManager = 0L;

@implementation PluginManager

- (void) setMenus:(NSMenu*) filtersMenu :(NSMenu*) roisMenu :(NSMenu*) othersMenu :(NSMenu*) dbMenu
{
	NSEnumerator *enumerator = [pluginsDict objectEnumerator];
	NSBundle *plugin;
	
	while ((plugin = [enumerator nextObject]))
	{
		NSString	*pluginName = [[plugin infoDictionary] objectForKey:@"CFBundleExecutable"];
		NSString	*pluginType = [[plugin infoDictionary] objectForKey:@"pluginType"];
		NSArray		*menuTitles = [[plugin infoDictionary] objectForKey:@"MenuTitles"];
	
		if( menuTitles)
		{
			if( [menuTitles count] > 1)
			{
				// Create a sub menu item
				
				NSMenu  *subMenu = [[[NSMenu alloc] initWithTitle: pluginName] autorelease];
				long	i;
				
				for( i = 0; i < [menuTitles count]; i++)
				{
					NSString *menuTitle = [menuTitles objectAtIndex: i];
					NSMenuItem *item = [[[NSMenuItem alloc] init] autorelease];
					[item setTitle:menuTitle];
					
					if( [pluginType isEqualToString:@"fusionFilter"])
					{
						[item setTag:-1];		// Useful for fusionFilter
						[item setAction:@selector(endBlendingType:)];
					}
					else if( [pluginType isEqualToString:@"Database"] || [pluginType isEqualToString:@"Report"]){
						[item setTarget:browserWindow];	//  browserWindow responds to DB plugins
						[item setAction:@selector(executeFilterDB:)];
					}
					else
					{
						[item setTarget:0L];	// FIRST RESPONDER !
						[item setAction:@selector(executeFilter:)];
					}
					
					[subMenu insertItem:item atIndex:[subMenu numberOfItems]];
				}
				
				id  subMenuItem;
				
				if( [pluginType isEqualToString:@"imageFilter"])
				{
					if( [filtersMenu indexOfItemWithTitle: pluginName] == -1)
					{
						subMenuItem = [filtersMenu insertItemWithTitle:pluginName action:0L keyEquivalent:@"" atIndex:[filtersMenu numberOfItems]];
						[filtersMenu setSubmenu:subMenu forItem:subMenuItem];
					}
				}
				else if( [pluginType isEqualToString:@"roiTool"])
				{
					if( [roisMenu indexOfItemWithTitle: pluginName] == -1)
					{
						subMenuItem = [roisMenu insertItemWithTitle:pluginName action:0L keyEquivalent:@"" atIndex:[roisMenu numberOfItems]];
						[roisMenu setSubmenu:subMenu forItem:subMenuItem];
					}
				}
				else if( [pluginType isEqualToString:@"fusionFilter"])
				{
					if( [fusionPluginsMenu indexOfItemWithTitle: pluginName] == -1)
					{
						subMenuItem = [fusionPluginsMenu insertItemWithTitle:pluginName action:0L keyEquivalent:@"" atIndex:[roisMenu numberOfItems]];
						[fusionPluginsMenu setSubmenu:subMenu forItem:subMenuItem];
					}
				}
				else if( [pluginType isEqualToString:@"Database"])
				{
					if( [dbMenu indexOfItemWithTitle: pluginName] == -1)
					{
						subMenuItem = [dbMenu insertItemWithTitle:pluginName action:0L keyEquivalent:@"" atIndex:[dbMenu numberOfItems]];
						[dbMenu setSubmenu:subMenu forItem:subMenuItem];
					}
				} 
				else
				{
					if( [othersMenu indexOfItemWithTitle: pluginName] == -1)
					{
						subMenuItem = [othersMenu insertItemWithTitle:pluginName action:0L keyEquivalent:@"" atIndex:[othersMenu numberOfItems]];
						[othersMenu setSubmenu:subMenu forItem:subMenuItem];
					}
				}
			}
			else
			{
				// Create a menu item
				
				NSMenuItem *item = [[[NSMenuItem alloc] init] autorelease];
				
				[item setTitle: [menuTitles objectAtIndex: 0]];	//pluginName];
				
				if( [pluginType isEqualToString:@"fusionFilter"])
				{
					[item setTag:-1];		// Useful for fusionFilter
					[item setAction:@selector(endBlendingType:)];
				}
				else if( [pluginType isEqualToString:@"Database"] || [pluginType isEqualToString:@"Report"])
				{
					[item setTarget:browserWindow];	//  browserWindow responds to DB plugins
					[item setAction:@selector(executeFilterDB:)];
				}
				else
				{
					[item setTarget:0L];	// FIRST RESPONDER !
					[item setAction:@selector(executeFilter:)];
				}
				
				if( [pluginType isEqualToString:@"imageFilter"])		[filtersMenu insertItem:item atIndex:[filtersMenu numberOfItems]];
				else if( [pluginType isEqualToString:@"roiTool"])		[roisMenu insertItem:item atIndex:[roisMenu numberOfItems]];
				else if( [pluginType isEqualToString:@"fusionFilter"])	[fusionPluginsMenu insertItem:item atIndex:[fusionPluginsMenu numberOfItems]];
				else if( [pluginType isEqualToString:@"Database"])		[dbMenu insertItem:item atIndex:[dbMenu numberOfItems]];
				else [othersMenu insertItem:item atIndex:[othersMenu numberOfItems]];
			}
		}
	}
	
	if( [filtersMenu numberOfItems] < 1)
	{
		NSMenuItem *item = [[[NSMenuItem alloc] init] autorelease];
		[item setTitle:NSLocalizedString(@"No plugins available for this menu", nil)];
		[item setTarget:self];
		[item setAction:@selector(noPlugins:)]; 
		
		[filtersMenu insertItem:item atIndex:0];
	}
	
	if( [roisMenu numberOfItems] < 1)
	{
		NSMenuItem *item = [[[NSMenuItem alloc] init] autorelease];
		[item setTitle:NSLocalizedString(@"No plugins available for this menu", nil)];
		[item setTarget:self];
		[item setAction:@selector(noPlugins:)];
		
		[roisMenu insertItem:item atIndex:0];
	}
	
	if( [othersMenu numberOfItems] < 1)
	{
		NSMenuItem *item = [[[NSMenuItem alloc] init] autorelease];
		[item setTitle:NSLocalizedString(@"No plugins available for this menu", nil)];
		[item setTarget:self];
		[item setAction:@selector(noPlugins:)];
		
		[othersMenu insertItem:item atIndex:0];
	}
	
	if( [fusionPluginsMenu numberOfItems] < 1)
	{
		NSMenuItem *item = [[[NSMenuItem alloc] init] autorelease];
		[item setTitle:NSLocalizedString(@"No plugins available for this menu", nil)];
		[item setTarget:self];
		[item setAction:@selector(noPlugins:)];
		
		[fusionPluginsMenu insertItem:item atIndex:0];
	}
	
	if( [dbMenu numberOfItems] < 1)
	{
		NSMenuItem *item = [[[NSMenuItem alloc] init] autorelease];
		[item setTitle:NSLocalizedString(@"No plugins available for this menu", nil)];
		[item setTarget:self];
		[item setAction:@selector(noPlugins:)];
		
		[dbMenu insertItem:item atIndex:0];
	}
	
	NSEnumerator *pluginEnum = [plugins objectEnumerator];
	PluginFilter *pluginFilter;
	
	while ( pluginFilter = [pluginEnum nextObject] ) {
		[pluginFilter setMenus];
	}
}

- (id)init {
	if (self = [super init])
	{
	// Set DefaultROINames *before* initializing plugins (which may change these)
	
	NSMutableArray *defaultROINames = [[NSMutableArray alloc] initWithCapacity:0];
	
	[defaultROINames addObject:@"ROI 1"];
	[defaultROINames addObject:@"ROI 2"];
	[defaultROINames addObject:@"ROI 3"];
	[defaultROINames addObject:@"ROI 4"];
	[defaultROINames addObject:@"ROI 5"];
	[defaultROINames addObject:@"-"];
	[defaultROINames addObject:@"DiasLength"];
	[defaultROINames addObject:@"SystLength"];
	[defaultROINames addObject:@"-"];
	[defaultROINames addObject:@"DiasLong"];
	[defaultROINames addObject:@"SystLong"];
	[defaultROINames addObject:@"-"];
	[defaultROINames addObject:@"DiasHorLong"];
	[defaultROINames addObject:@"SystHorLong"];
	[defaultROINames addObject:@"DiasVerLong"];
	[defaultROINames addObject:@"SystVerLong"];
	[defaultROINames addObject:@"-"];
	[defaultROINames addObject:@"DiasShort"];
	[defaultROINames addObject:@"SystShort"];
	[defaultROINames addObject:@"-"];
	[defaultROINames addObject:@"DiasMitral"];
	[defaultROINames addObject:@"SystMitral"];
	[defaultROINames addObject:@"DiasPapi"];
	[defaultROINames addObject:@"SystPapi"];
	
	[ViewerController setDefaultROINames: defaultROINames];
	
    [self discoverPlugins];
	//[self testGUIfunctions];
	}
	return self;
}

- (NSString*) pathResolved:(NSString*) inPath
{
	CFStringRef resolvedPath = nil;
	CFURLRef	url = CFURLCreateWithFileSystemPath(NULL /*allocator*/, (CFStringRef)inPath, kCFURLPOSIXPathStyle, NO /*isDirectory*/);
	if (url != NULL) {
		FSRef fsRef;
		if (CFURLGetFSRef(url, &fsRef)) {
			Boolean targetIsFolder, wasAliased;
			if (FSResolveAliasFile (&fsRef, true /*resolveAliasChains*/, &targetIsFolder, &wasAliased) == noErr && wasAliased) {
				CFURLRef resolvedurl = CFURLCreateFromFSRef(NULL /*allocator*/, &fsRef);
				if (resolvedurl != NULL) {
					resolvedPath = CFURLCopyFileSystemPath(resolvedurl, kCFURLPOSIXPathStyle);
					CFRelease(resolvedurl);
				}
			}
		}
		CFRelease(url);
	}
	
	if( resolvedPath == 0L) return inPath;
	else return (NSString *)resolvedPath;
}

- (void) discoverPlugins
{
	BOOL		conflict = NO;
    Class		filterClass;
    NSString	*appSupport = @"Library/Application Support/OsiriX/";
    long		i;
	NSString	*appPath = [[NSBundle mainBundle] builtInPlugInsPath];
    NSString	*userPath = [NSHomeDirectory() stringByAppendingPathComponent:appSupport];
    NSString	*sysPath = [@"/" stringByAppendingPathComponent:appSupport];
    
	if ([[NSFileManager defaultManager] fileExistsAtPath:appPath] == NO) [[NSFileManager defaultManager] createDirectoryAtPath:appPath attributes:nil];
	if ([[NSFileManager defaultManager] fileExistsAtPath:userPath] == NO) [[NSFileManager defaultManager] createDirectoryAtPath:userPath attributes:nil];
	if ([[NSFileManager defaultManager] fileExistsAtPath:sysPath] == NO) [[NSFileManager defaultManager] createDirectoryAtPath:sysPath attributes:nil];
	
    appSupport = [appSupport stringByAppendingPathComponent :@"Plugins/"];
	
	userPath = [NSHomeDirectory() stringByAppendingPathComponent:appSupport];
	sysPath = [@"/" stringByAppendingPathComponent:appSupport];
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:userPath] == NO) [[NSFileManager defaultManager] createDirectoryAtPath:userPath attributes:nil];
	if ([[NSFileManager defaultManager] fileExistsAtPath:sysPath] == NO) [[NSFileManager defaultManager] createDirectoryAtPath:sysPath attributes:nil];
	
	NSArray *paths = [NSArray arrayWithObjects:appPath, userPath, sysPath, nil];
    NSEnumerator *pathEnum = [paths objectEnumerator];
    NSString *path;
	
    plugins = [[NSMutableDictionary alloc] init];
	pluginsDict = [[NSMutableDictionary alloc] init];
	fileFormatPlugins = [[NSMutableDictionary alloc] init];
	preProcessPlugins = [[NSMutableArray alloc] initWithCapacity:0];
	reportPlugins = [[NSMutableDictionary alloc] init];
	
	fusionPluginsMenu = [[NSMenu alloc] initWithTitle:@""];
	[fusionPluginsMenu insertItemWithTitle:NSLocalizedString(@"Select a fusion plug-in", nil) action:0L keyEquivalent:@"" atIndex:0];
	
    while ( path = [pathEnum nextObject] )
	{
		NSEnumerator *e = [[[NSFileManager defaultManager] directoryContentsAtPath:path] objectEnumerator];
		NSString *name;
		
		while ( name = [e nextObject] )
		{
			if ( [[name pathExtension] isEqualToString:@"plugin"] )
			{
				NSBundle *plugin = [NSBundle bundleWithPath:[self pathResolved:[path stringByAppendingPathComponent:name]]];
				 
				if (filterClass = [plugin principalClass])	
				{
					if ([[[plugin infoDictionary] objectForKey:@"pluginType"] isEqualToString:@"Pre-Process"]) 
					{
						PluginFilter*	filter = [filterClass filter];
						[preProcessPlugins addObject: filter];
					}

					else if ([[plugin infoDictionary] objectForKey:@"FileFormats"]) 
					{
						NSEnumerator *enumerator = [[[plugin infoDictionary] objectForKey:@"FileFormats"] objectEnumerator];
						NSString *fileFormat;
						while (fileFormat = [enumerator nextObject])
						{
							//we will save the bundle rather than a filter.  Each file decode will require a separate decoder
							[fileFormatPlugins setObject:plugin forKey:fileFormat];
						}
					}
					else if ( [filterClass instancesRespondToSelector:@selector(filterImage:)] )
					{
						NSString	*pluginName = [[plugin infoDictionary] objectForKey:@"CFBundleExecutable"];
						NSString	*pluginType = [[plugin infoDictionary] objectForKey:@"pluginType"];
						NSArray		*menuTitles = [[plugin infoDictionary] objectForKey:@"MenuTitles"];
						
						if( menuTitles)
						{
							PluginFilter*	filter = [filterClass filter];
						
							if( [menuTitles count] > 1)
							{
								long	i;
								
								for( i = 0; i < [menuTitles count]; i++)
								{
									NSString *menuTitle = [menuTitles objectAtIndex: i];
									
									[plugins setObject:filter forKey:menuTitle];
									[pluginsDict setObject:plugin forKey:menuTitle];
								}
							}
							else
							{
								[plugins setObject:filter forKey: [menuTitles objectAtIndex: 0]];
								[pluginsDict setObject:plugin forKey:[menuTitles objectAtIndex: 0]];
							}
						}
					}
					
					if ([[[plugin infoDictionary] objectForKey:@"pluginType"] isEqualToString:@"Report"]) 
					{
						[reportPlugins setObject: plugin forKey:[[plugin infoDictionary] objectForKey:@"CFBundleExecutable"]];
					}
				}
			}
		}
    }
}

-(void) noPlugins:(id) sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://homepage.mac.com/rossetantoine/osirix/Plugins.html"]];
}

#pragma mark -
#pragma mark Plugin user management

#pragma mark directories

- (NSString*)activePluginsDirectoryPath;
{
	return @"Library/Application Support/OsiriX/Plugins/";
}

- (NSString*)inactivePluginsDirectoryPath;
{
	return @"Library/Application Support/OsiriX/Plugins (off)/";
}

- (NSString*)userActivePluginsDirectoryPath;
{
	return [NSHomeDirectory() stringByAppendingPathComponent:[self activePluginsDirectoryPath]];
}

- (NSString*)userInactivePluginsDirectoryPath;
{
	return [NSHomeDirectory() stringByAppendingPathComponent:[self inactivePluginsDirectoryPath]];
}

- (NSString*)systemActivePluginsDirectoryPath;
{
	NSString *s = @"/";
	return [s stringByAppendingPathComponent:[self activePluginsDirectoryPath]];
}

- (NSString*)systemInactivePluginsDirectoryPath;
{
	NSString *s = @"/";
	return [s stringByAppendingPathComponent:[self inactivePluginsDirectoryPath]];
}

- (NSString*)appActivePluginsDirectoryPath;
{
	return [[NSBundle mainBundle] builtInPlugInsPath];
}

- (NSString*)appInactivePluginsDirectoryPath;
{
	NSMutableString *appPath = [NSMutableString stringWithString:[[NSBundle mainBundle] builtInPlugInsPath]];
	[appPath appendString:@" (off)"];
	return appPath;
}

- (NSArray*)activeDirectories;
{
	return [NSArray arrayWithObjects:[self userActivePluginsDirectoryPath], [self systemActivePluginsDirectoryPath], [self appActivePluginsDirectoryPath], nil];
}

- (NSArray*)inactiveDirectories;
{
	return [NSArray arrayWithObjects:[self userInactivePluginsDirectoryPath], [self systemInactivePluginsDirectoryPath], [self appInactivePluginsDirectoryPath], nil];
}

#pragma mark activation

//- (BOOL)pluginIsActiveForName:(NSString*)pluginName;
//{
//	NSMutableArray *paths = [NSMutableArray arrayWithCapacity:0];
//	[paths addObjectsFromArray:[self activeDirectories]];
//	
//	NSEnumerator *pathEnum = [paths objectEnumerator];
//    NSString *path;
//	while(path=[pathEnum nextObject])
//	{
//		NSEnumerator *e = [[[NSFileManager defaultManager] directoryContentsAtPath:path] objectEnumerator];
//		NSString *name;
//		while(name = [e nextObject])
//		{
//			if([[name stringByDeletingPathExtension] isEqualToString:pluginName])
//			{
//				return YES;
//			}
//		}
//	}
//	
//	return NO;
//}

- (void)movePluginFromPath:(NSString*)sourcePath toPath:(NSString*)destinationPath;
{
	NSTask *aTask = [[NSTask alloc] init];
    NSMutableArray *args = [NSMutableArray array];

    [args addObject:sourcePath];
    [args addObject:destinationPath];
    [aTask setLaunchPath:@"/bin/mv"];
    [aTask setArguments:args];
    [aTask launch];
}

- (void)activatePluginWithName:(NSString*)pluginName;
{
	NSMutableArray *activePaths = [NSMutableArray arrayWithArray:[self activeDirectories]];
	NSMutableArray *inactivePaths = [NSMutableArray arrayWithArray:[self inactiveDirectories]];
	
	NSEnumerator *activePathEnum = [activePaths objectEnumerator];
    NSString *activePath;
	NSEnumerator *inactivePathEnum = [inactivePaths objectEnumerator];
    NSString *inactivePath;
	
	while(inactivePath = [inactivePathEnum nextObject])
	{
		activePath = [activePathEnum nextObject];
		NSEnumerator *e = [[[NSFileManager defaultManager] directoryContentsAtPath:inactivePath] objectEnumerator];
		NSString *name;
		while(name = [e nextObject])
		{
			if([[name stringByDeletingPathExtension] isEqualToString:pluginName])
			{
				NSString *sourcePath = [NSString stringWithFormat:@"%@/%@", inactivePath, name];
				NSString *destinationPath = [NSString stringWithFormat:@"%@/%@", activePath, name];
				[self movePluginFromPath:sourcePath toPath:destinationPath];
			}
		}
	}
}

- (void)desactivatePluginWithName:(NSString*)pluginName;
{
	NSMutableArray *activePaths = [NSMutableArray arrayWithArray:[self activeDirectories]];
	NSMutableArray *inactivePaths = [NSMutableArray arrayWithArray:[self inactiveDirectories]];
	
	NSEnumerator *activePathEnum = [activePaths objectEnumerator];
    NSString *activePath;
	NSEnumerator *inactivePathEnum = [inactivePaths objectEnumerator];
    NSString *inactivePath;
	
	while(activePath = [activePathEnum nextObject])
	{
		inactivePath = [inactivePathEnum nextObject];
		NSEnumerator *e = [[[NSFileManager defaultManager] directoryContentsAtPath:activePath] objectEnumerator];
		NSString *name;
		while(name = [e nextObject])
		{
			if([[name stringByDeletingPathExtension] isEqualToString:pluginName])
			{
				BOOL isDir = YES;
				if (![[NSFileManager defaultManager] fileExistsAtPath:inactivePath isDirectory:&isDir] && isDir)
					[[NSFileManager defaultManager] createDirectoryAtPath:inactivePath attributes:nil];
				NSString *sourcePath = [NSString stringWithFormat:@"%@/%@", activePath, name];
				NSString *destinationPath = [NSString stringWithFormat:@"%@/%@", inactivePath, name];
				[self movePluginFromPath:sourcePath toPath:destinationPath];
			}
		}
	}
}

#pragma mark plugins

int sortPluginArray(id plugin1, id plugin2, void *context)
{
    NSString *name1 = [plugin1 objectForKey:@"name"];
    NSString *name2 = [plugin2 objectForKey:@"name"];
    
	return [name1 compare:name2];
}

- (NSArray*)pluginsList;
{
	NSString *userActivePath = [self userActivePluginsDirectoryPath];
	NSString *userInactivePath = [self userInactivePluginsDirectoryPath];
	NSString *sysActivePath = [self systemActivePluginsDirectoryPath];
	NSString *sysInactivePath = [self systemInactivePluginsDirectoryPath];

//	NSArray *paths = [NSArray arrayWithObjects:userActivePath, userInactivePath, sysActivePath, sysInactivePath, nil];
	
	NSMutableArray *paths = [NSMutableArray arrayWithCapacity:0];
	[paths addObjectsFromArray:[self activeDirectories]];
	[paths addObjectsFromArray:[self inactiveDirectories]];
	
    NSEnumerator *pathEnum = [paths objectEnumerator];
    NSString *path;
	
    NSMutableArray *plugins = [[NSMutableArray alloc] init];
	Class filterClass;
    while(path=[pathEnum nextObject])
	{
//		BOOL active = ([path isEqualToString:userActivePath] || [path isEqualToString:sysActivePath]);
//		BOOL allUsers = ([path isEqualToString:sysActivePath] || [path isEqualToString:sysInactivePath]);
		BOOL active = [[self activeDirectories] containsObject:path];
		BOOL allUsers = ([path isEqualToString:sysActivePath] || [path isEqualToString:sysInactivePath] || [path isEqualToString:[self appActivePluginsDirectoryPath]] || [path isEqualToString:[self appInactivePluginsDirectoryPath]]);
		
		NSEnumerator *e = [[[NSFileManager defaultManager] directoryContentsAtPath:path] objectEnumerator];
		NSString *name;
		while(name = [e nextObject])
		{
			if([[name pathExtension] isEqualToString:@"plugin"])
			{
				NSBundle *plugin = [NSBundle bundleWithPath:[self pathResolved:[path stringByAppendingPathComponent:name]]];
				if (filterClass = [plugin principalClass])	
				{
					NSMutableDictionary *pluginDescription = [NSMutableDictionary dictionaryWithCapacity:3];
					[pluginDescription setObject:[name stringByDeletingPathExtension] forKey:@"name"];
					[pluginDescription setObject:[NSNumber numberWithBool:active] forKey:@"active"];
					[pluginDescription setObject:[NSNumber numberWithBool:allUsers] forKey:@"allUsers"];
					
					[plugins addObject:pluginDescription];
				}
			}
		}
	}
	NSArray *sortedPlugins = [plugins sortedArrayUsingFunction:sortPluginArray context:NULL];
	return sortedPlugins;
}

#pragma mark -
#pragma mark Test

- (void)testGUIfunctions;
{
	NSLog(@"------------------------");
	NSLog(@"plugin Manager testGUIfunctions");
	NSLog(@"common active : %@", [self activePluginsDirectoryPath]);
	NSLog(@"common inactive : %@", [self inactivePluginsDirectoryPath]);
	NSLog(@"user active : %@", [self userActivePluginsDirectoryPath]);
	NSLog(@"user inactive : %@", [self userInactivePluginsDirectoryPath]);
	NSLog(@"sys active : %@", [self systemActivePluginsDirectoryPath]);
	NSLog(@"sys inactive : %@", [self systemInactivePluginsDirectoryPath]);

	NSLog(@"app active : %@", [self appActivePluginsDirectoryPath]);
	NSLog(@"app inactive : %@", [self appInactivePluginsDirectoryPath]);	
	
	NSLog(@"Plugin list (sorted) : %@", [self pluginsList]);
	
//	if([self pluginIsActiveForName:@"Cobb"])
//		NSLog(@"Cobb active");
//	if([self pluginIsActiveForName:@"Michel"])
//		NSLog(@"Michel active");

	//[self movePluginFromPath:@"/Library/Application\ Support/OsiriX/Plugins/Ejection\ Fraction.plugin/" toPath:@"/Library/Application\ Support/OsiriX/Ejection\ Fraction.plugin/"];
	//[self activatePluginWithName:@"Ejection Fraction"];
//	[self activatePluginWithName:@"baloo"];
	NSLog(@"------------------------");
}

@end
