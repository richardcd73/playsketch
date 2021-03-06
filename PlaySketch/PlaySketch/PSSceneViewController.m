/*
 
 --------------
 Copyright 2012 Singapore Management University
 
 This Source Code Form is subject to the terms of the
 Mozilla Public License, v. 2.0. If a copy of the MPL was
 not distributed with this file, You can obtain one at
 http://mozilla.org/MPL/2.0/.
 --------------
 
 */

#import "PSSceneViewController.h"
#import "PSDataModel.h"
#import "PSAnimationRenderingController.h"
#import "PSDrawingEventsView.h"
#import "PSSelectionHelper.h"
#import "PSSRTManipulator.h"
#import "PSHelpers.h"
#import "PSTimelineSlider.h"
#import "PSGroupOverlayButtons.h"
#import "PSVideoExportControllerViewController.h"
#import "PSMotionPathView.h"
#import "PSRecordingSession.h"
#import "PSKeyframeView.h"
#import "PSGraphicConstants.h"
#import <QuartzCore/QuartzCore.h>

/* Private properties and function */
@interface PSSceneViewController ()
@property(nonatomic)BOOL isSelecting; // If we are selecting instead of drawing
@property(nonatomic)BOOL isErasing;
@property(nonatomic)BOOL isReadyToRecord; // If manipulations should be treated as recording
@property(nonatomic)BOOL isRecording;
@property(nonatomic,retain) UIPopoverController* penPopoverController;
@property(nonatomic,retain) PSPenColorViewController* penController;
@property(nonatomic) UInt64 currentColor; // the drawing color as an int
@property(nonatomic) int penWeight;
@property(nonatomic,retain) PSRecordingSession* recordingSession;
@property(nonatomic)BOOL insideEraseGroup;
- (void)refreshInterfaceAfterDataChange:(BOOL)dataMayHaveChanged selectionChange:(BOOL)selectionMayHaveChanged;
- (void)highlightButton:(UIButton*)b on:(BOOL)highlight;
@end



@implementation PSSceneViewController


/*
 ----------------------------------------------------------------------------
 Standard View Controller Lifecycle Methods
 (read the documentation for UIViewController to see when they are triggered)
 ----------------------------------------------------------------------------
 */

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	// Add the renderingview to our viewcontroller hierarchy
	[self addChildViewController:self.renderingController];
	[self.renderingController viewDidLoad];
	
	// Start off in drawing mode
	self.isReadyToRecord = NO;
	self.isRecording = NO;
	self.insideEraseGroup = NO;
	[self startDrawing:nil];

	
	// Create the manipulator
	self.manipulator = [[PSSRTManipulator alloc] initAtLocation:CGPointZero];
	[self.renderingController.view addSubview:self.manipulator];
	self.manipulator.delegate = self;
	self.manipulator.groupButtons = self.selectionOverlayButtons;
	
	// Initialize to be drawing with an initial color
	UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"SketchInterface" bundle:nil];
	self.penController = [storyboard instantiateViewControllerWithIdentifier:@"PenController"];
	self.penController.delegate = self;
	self.penPopoverController = [[UIPopoverController alloc] initWithContentViewController:self.penController];
	[self.penController setToDefaults];
	
	
	// initialize our objects to the right time
	[self.renderingController jumpToTime:self.timelineSlider.value];
		
}


- (void)viewDidUnload
{
    [super viewDidUnload];

	// Zero out the non-IB references we are keeping
	self.currentDocument = nil;
	self.rootGroup = nil;
	self.penPopoverController = nil;
	self.penController = nil;
	self.recordingSession = nil;
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return UIInterfaceOrientationIsLandscape(interfaceOrientation);
}

- (void) viewWillAppear:(BOOL)animated
{
	// Don't let us undo past this point
	[PSDataModel clearUndoStack];
	
	self.keyframeView.rootGroup = self.rootGroup;
	
	self.timelineSlider.maximumValue = [self.currentDocument.duration floatValue];
	[self.keyframeView refreshAll];
	
	self.motionPathView.rootGroup = self.rootGroup;
	
	[self refreshInterfaceAfterDataChange:YES selectionChange:YES];
}


- (void) viewWillDisappear:(BOOL)animated
{
	// Save a preview image of our drawing before going away!
	// First we snapshot the contents of our rendering view,
	// Then we convert that to a format that will fit in our data store
	// TODO: the last line of this seems to take a while: downsample before snapshot?
	[PSSelectionHelper resetSelection];
	GLKView* view = (GLKView*)self.renderingController.view;
	UIImage* previewImg = [view snapshot];
	UIImage* previewImgSmall = [PSHelpers imageWithImage:previewImg scaledToSize:CGSizeMake(462, 300)];
	self.currentDocument.previewImage = UIImagePNGRepresentation(previewImgSmall);
	[PSDataModel save];

	// Don't let us undo past this point
	[PSDataModel clearUndoStack];
}


/*
 ----------------------------------------------------------------------------
 IBActions for the storyboard
 (methods with a return type of "IBAction" can be triggered by buttons in the 
 storyboard editor
 ----------------------------------------------------------------------------
 */

- (IBAction)dismissSceneView:(id)sender
{
	[self dismissModalViewControllerAnimated:YES];
}


- (IBAction)playPressed:(id)sender
{
	[self setPlaying:!self.timelineSlider.playing];
}


- (IBAction)timelineScrubbed:(id)sender
{
	self.timelineSlider.playing = NO;
	[self.renderingController jumpToTime:self.timelineSlider.value];
	[self refreshInterfaceAfterDataChange:NO selectionChange:NO];
}


- (IBAction)toggleRecording:(id)sender
{
	self.isReadyToRecord = ! self.isReadyToRecord;
}


- (IBAction)exportAsVideo:(id)sender
{
	//Push a new View Controller
	UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"SketchInterface" bundle:nil];
	PSVideoExportControllerViewController *vc = [storyboard instantiateViewControllerWithIdentifier:@"VideoExportViewController"];
	vc.renderingController = self.renderingController;
	vc.document = self.currentDocument;
	[vc setModalPresentationStyle:UIModalPresentationFormSheet];
	[self presentModalViewController:vc animated:YES];

}


- (IBAction)snapTimeline:(id)sender
{
	// Round it to the nearest frame and update the UI
	float beforeSnapping = self.timelineSlider.value;
	float afterSnapping = roundf(beforeSnapping * POSITION_FPS) / (float)POSITION_FPS;
	if(afterSnapping != beforeSnapping)
	{
		[self.timelineSlider setValue:afterSnapping animated:YES];
		[self timelineScrubbed:nil];
	}
}


- (IBAction)showPenPopover:(id)sender
{
	[self.penPopoverController presentPopoverFromRect:[sender frame]
											   inView:self.view
							 permittedArrowDirections:UIPopoverArrowDirectionUp
											 animated:YES];
	
}


- (IBAction)startSelecting:(id)sender
{
	[self highlightButton:self.startSelectingButton on:YES];
	[self highlightButton:self.startDrawingButton on:NO];
	[self highlightButton:self.startErasingButton on:NO];
	self.isSelecting = YES;
	self.isErasing = NO;	
}


- (IBAction)startDrawing:(id)sender
{
	[self highlightButton:self.startSelectingButton on:NO];
	[self highlightButton:self.startDrawingButton on:YES];
	[self highlightButton:self.startErasingButton on:NO];
	self.isSelecting = NO;
	self.isErasing = NO;
}


- (IBAction)startErasing:(id)sender
{
	[self highlightButton:self.startSelectingButton on:NO];
	[self highlightButton:self.startDrawingButton on:NO];
	[self highlightButton:self.startErasingButton on:YES];
	self.isSelecting = NO;
	self.isErasing = YES;
}


- (IBAction)deleteCurrentSelection:(id)sender
{
	[self.rootGroup deleteSelectedChildren];
	[PSSelectionHelper resetSelection];
	[self refreshInterfaceAfterDataChange:YES selectionChange:YES];
}


- (IBAction)createGroupFromCurrentSelection:(id)sender
{
	[PSHelpers assert:([PSSelectionHelper selectedGroupCount] > 1)
		  withMessage:@"Need more than one existing group to create a new one"];
	
	PSDrawingGroup* newGroup = [self.rootGroup mergeSelectedChildrenIntoNewGroup];
	
	// Insert new keyframe
	SRTPosition newPosition = SRTPositionZero();
	newPosition.timeStamp = self.timelineSlider.value;
	[newGroup addPosition:newPosition withInterpolation:NO];
	
	[newGroup centerOnCurrentBoundingBox];
	[newGroup jumpToTime:self.timelineSlider.value];
	
	
	//Manually update our selection
	[PSSelectionHelper manuallySetSelectedGroup:newGroup];
	
	[self refreshInterfaceAfterDataChange:YES selectionChange:YES];
}


- (IBAction)ungroupFromCurrentSelection:(id)sender
{
	PSDrawingGroup* topLevelGroup = [self.rootGroup topLevelSelectedChild];
	[PSHelpers assert:(topLevelGroup!=nil) withMessage:@"Need a non-nil child"];
	[PSHelpers assert:(topLevelGroup!=self.rootGroup) withMessage:@"Selected child can't be the root"];
	[topLevelGroup breakUpGroupAndMergeIntoParent];
	[PSSelectionHelper resetSelection];
	[self refreshInterfaceAfterDataChange:YES selectionChange:YES];
}


- (IBAction)markCurrentSelectionVisible:(id)sender
{
	[self.rootGroup applyToSelectedSubTrees:^(PSDrawingGroup *g) {
		[g setVisibility:YES atTime:self.timelineSlider.value];
	}];
	
	[self refreshInterfaceAfterDataChange:YES selectionChange:YES];
}


- (IBAction)markCurrentSelectionNotVisible:(id)sender
{
	[self.rootGroup applyToSelectedSubTrees:^(PSDrawingGroup *g) {
		[g setVisibility:NO atTime:self.timelineSlider.value];
	}];

	[self refreshInterfaceAfterDataChange:YES selectionChange:YES];
}


- (IBAction)undo:(id)sender
{
	[PSDataModel undo];
	[self.rootGroup jumpToTime:self.timelineSlider.value];
	[PSSelectionHelper resetSelection];
	[self refreshInterfaceAfterDataChange:YES selectionChange:YES];
}


- (IBAction)redo:(id)sender
{
	[PSDataModel redo];
	[self.rootGroup jumpToTime:self.timelineSlider.value];
	[PSSelectionHelper resetSelection];
	[self refreshInterfaceAfterDataChange:YES selectionChange:YES];
}


/*
 ----------------------------------------------------------------------------
 Private functions
 (they are private because they are declared at the top of this file instead of
 in the .h file)
 ----------------------------------------------------------------------------
 */

- (void)refreshInterfaceAfterDataChange:(BOOL)dataMayHaveChanged selectionChange:(BOOL)selectionMayHaveChanged
{
	//Refresh the undo/redo buttons
	self.undoButton.enabled = [PSDataModel canUndo];
	self.redoButton.enabled = [PSDataModel canRedo];

	// Hide/show the manipulator
	BOOL shouldShow =	[PSSelectionHelper selectedGroupCount] > 0 &&
						(!self.timelineSlider.playing || self.isRecording );
	self.manipulator.hidden = !shouldShow;
	

	// Update the manipulator's location
	if(shouldShow && [PSSelectionHelper selectedGroupCount] == 1)
	{
		PSDrawingGroup* group = [self.rootGroup topLevelSelectedChild];
		self.manipulator.center = [group currentOriginInWorldCoordinates];
	}
	else if(shouldShow)
	{
		self.manipulator.center = CGPointZero;
	}
	
	// Update the buttons attached to the manipulator
	BOOL currentlyVisible = ![PSSelectionHelper isSingleLeafOnlySelected] ||
							 [PSSelectionHelper leafGroup].currentCachedPosition.isVisible;
	[self.selectionOverlayButtons configureForSelectionCount:[PSSelectionHelper selectedGroupCount]
												isLeafObject:[PSSelectionHelper isSingleLeafOnlySelected]
												   isVisible:currentlyVisible];
	
	if(dataMayHaveChanged)
		[self.keyframeView refreshAll];
	
	// Motion paths
	self.motionPathView.hidden = self.timelineSlider.playing;
	if(selectionMayHaveChanged)
		[self.motionPathView refreshSelected];
}

- (void)highlightButton:(UIButton*)b on:(BOOL)highlight
{
	if(highlight)
	{
		b.layer.shadowRadius = 10.0;
		b.layer.shadowColor = HIGHLIGHTED_BUTTON_UICOLOR.CGColor;
		b.layer.shadowOffset = CGSizeMake(0,0);
		b.layer.shadowOpacity = 1.0;
	}
	else
	{
		b.layer.shadowRadius = 0.0;
		b.layer.shadowOpacity = 0.0;
	}
}


/*
 ----------------------------------------------------------------------------
 Property Setters
 @property generates a default pair of get/set methods
 You can override any of them here to customize behavior
 These are also called if you use dot-notaion: foo.currentDocument
 The real instance variable is called _currentDocument, by default.
 ----------------------------------------------------------------------------
 */



- (void)setPlaying:(BOOL)playing
{
	if(!playing && self.timelineSlider.playing)
	{
		// PAUSE
		[self.renderingController stopPlaying];
		self.timelineSlider.playing = NO;
	}
	else if(playing && !self.timelineSlider.playing)
	{
		// PLAY!
		float time = self.timelineSlider.value;
		[self.renderingController playFromTime:time];
		self.timelineSlider.value = time;
		self.timelineSlider.playing = YES;
	}
	
	[self refreshInterfaceAfterDataChange:NO selectionChange:NO];
}


- (void)setCurrentDocument:(PSDrawingDocument *)currentDocument
{
	_currentDocument = currentDocument;
	//Also tell the rendering controller about the document to render it
	self.renderingController.currentDocument = currentDocument;
}


- (void)setRootGroup:(PSDrawingGroup *)rootGroup
{
	_rootGroup = rootGroup;
	[PSSelectionHelper setRootGroup:rootGroup];
}


- (void)setIsReadyToRecord:(BOOL)isReadyToRecord
{
	if(_isReadyToRecord && !isReadyToRecord)
	{
		//Stop Recording
		[self.selectionOverlayButtons stopRecordingMode];
	}
	
	if(!_isReadyToRecord && isReadyToRecord)
	{
		//Start Recording
		[self.selectionOverlayButtons startRecordingMode];
	}
	
	_isReadyToRecord = isReadyToRecord;
}


/*
 ----------------------------------------------------------------------------
 PSDrawingEventsViewDrawingDelegate methods
 (Called by our drawing view when it needs to do something with touch events)
 ----------------------------------------------------------------------------
 */


/*	
 Provide a PSDrawingLine based on whether we are selecting or drawing
 */
- (PSDrawingLine*)newLineToDrawTo:(id)drawingView
{
	// If the manipulator is visible, clear the current selection and don't start a line
	if(!self.manipulator.hidden)
	{
		// Clear any current selection
		[PSSelectionHelper resetSelection];
		[self refreshInterfaceAfterDataChange:NO selectionChange:YES];
		return nil;
	}
	
	// No line necessary if we are erasing
	if (self.isErasing) return nil;
	
	// Create a new TEMPORARY line with the current color and weight
	// Read the comments on newTemporaryLineWithWeight:andColor: for an explanation
	// of why this line has to be "temporary"
	int weight = self.isSelecting ? SELECTION_PEN_WEIGHT : self.penWeight;
	UInt64 color = self.isSelecting ? [PSHelpers colorToInt64:argsToUIColor(SELECTION_COLOR)] : self.currentColor;
	PSDrawingLine* newLine = [PSDataModel newTemporaryLineWithWeight:weight andColor:color];
	
	// Start a new selection set helper to keep track of what's being selected
	if (self.isSelecting) [PSSelectionHelper resetSelection];
		
	// Tell the rendering controller to draw this line specially, since it isn't added to the scene yet
	self.renderingController.currentLine = newLine;

	return newLine;
}


- (void)addedToLine:(PSDrawingLine*)line fromPoint:(CGPoint)from toPoint:(CGPoint)to inDrawingView:(id)drawingView
{
	if (self.isSelecting)
	{
		// Give this new line segment to the selection helper to update the selected set
		
		// We want to add this line to the selectionHelper on a background
		// thread so it won't block the redrawing as much as possible
		// That requires us to bundle up the points as objects instead of structs
		// so they'll fit in a dictionary to pass to the performSelectorInBackground method
		// This is ugly-looking, but the arguments need to be on the heap instead of the stack
		NSDictionary* pointsDict = [NSDictionary dictionaryWithObjectsAndKeys:
									[NSValue valueWithCGPoint:from], @"from",
									[NSValue valueWithCGPoint:to], @"to", nil];
		[PSSelectionHelper performSelectorInBackground:@selector(addSelectionLineFromDict:)
											withObject:pointsDict];
	}
}


- (void)finishedDrawingLine:(PSDrawingLine*)line inDrawingView:(id)drawingView
{
	if (self.isErasing && self.insideEraseGroup)
	{
		// If we are erasing, finish off the undo group so it will all be undone togther
		[self.rootGroup applyToAllSubTrees:^(PSDrawingGroup* g, BOOL s) {
			for (PSDrawingLine* l in g.drawingLines)
				[l doneMutatingPoints];
		}];
		[PSDataModel save];
		[PSDataModel endUndoGroup];
		self.insideEraseGroup = NO;
	}
	else if ( line && self.isSelecting )
	{
		[PSSelectionHelper finishLassoSelection];
	}
	else if( line && !self.isSelecting)
	{
		// Create a new group for it
		PSDrawingGroup* newLineGroup = [PSDataModel newDrawingGroupWithParent:self.rootGroup];
		
		[PSDataModel makeTemporaryLinePermanent:line];
		line.group = newLineGroup;
		
		// Add a keyframe at time 0 to set the object as invisible:
		SRTPosition newPosition1 = SRTPositionZero();
		newPosition1.timeStamp = 0.0;
		newPosition1.isVisible = NO;
		newPosition1.keyframeType = SRTKeyframeMake(NO, NO, NO, NO);
		[newLineGroup addPosition:newPosition1 withInterpolation:NO];
		
		// Then add the real visible keyframe at the current time
		SRTPosition newPosition2 = SRTPositionZero();
		newPosition2.timeStamp = self.timelineSlider.value;
		newPosition2.isVisible = YES;
		newPosition2.keyframeType = SRTKeyframeMake(YES,YES,YES,YES);
		[newLineGroup addPosition:newPosition2 withInterpolation:NO];


		// Center it
		[line.group centerOnCurrentBoundingBox];
		[line.group jumpToTime:self.timelineSlider.value];

		// Save it
		[PSDataModel save];
	
	}
	
	self.renderingController.currentLine = nil;
	[self refreshInterfaceAfterDataChange:YES selectionChange:NO];
}


- (void)cancelledDrawingLine:(PSDrawingLine*)line inDrawingView:(id)drawingView
{
	self.renderingController.currentLine = nil;
	[PSSelectionHelper resetSelection];
}

- (void)movedAt:(CGPoint)p inDrawingView:(id)drawingView
{
	// We only care about this when we are erasing.
	// For drawing and selecting, we let the drawingView build a line
	if(self.isErasing)
	{
		if(!self.insideEraseGroup)
		{
			[PSDataModel beginUndoGroup];
			self.insideEraseGroup = YES;
		}

		[self.rootGroup eraseAtPoint:p];
	}
}


- (void)whileDrawingLine:(PSDrawingLine *)line tappedAt:(CGPoint)p tapCount:(int)tapCount inDrawingView:(id)drawingView
{
	if (self.isErasing ) return; // No need for any selection while erasing

	// Look to see if we tapped on an object!
	BOOL touchedObject = [PSSelectionHelper findSelectionForTap:p];

	// If we didn't hit anything, just treat it like a normal line that finished
	// Otherwise our selectionHelper will have the info about our selection
	if (!(tapCount == 1 && touchedObject))
	{
		[self finishedDrawingLine:line inDrawingView:drawingView];
	}
	
	self.renderingController.currentLine = nil;
	[self refreshInterfaceAfterDataChange:YES selectionChange:YES];
}

/*
 ----------------------------------------------------------------------------
 PSSRTManipulatoDelegate methods
 Called by our manipulator(s) when they are manipulated
 ----------------------------------------------------------------------------
 */

- (void)manipulatorDidStartInteraction:(id)sender
						willTranslate:(BOOL)isTranslating
						   willRotate:(BOOL)isRotating
							willScale:(BOOL)isScaling
{
	if(self.isReadyToRecord)
	{
		self.isRecording = YES;
	
		self.recordingSession = [self.rootGroup startSelectedGroupsRecordingTranslation:isTranslating
																			   rotation:isRotating
																				scaling:isScaling
																				 atTime:self.timelineSlider.value];
		// Start playing the timeline
		[self setPlaying:YES];
		self.selectionOverlayButtons.recordPulsing = YES;
	}
}

- (void)manipulator:(id)sender
   didTranslateByX:(float)dX
			andY:(float)dY
		  rotation:(float)dRotation
			 scale:(float)dScale
	 isTranslating:(BOOL)isTranslating
		isRotating:(BOOL)isRotating
		 isScaling:(BOOL)isScaling
	  timeDuration:(float)duration
{

	// Check if we need to expand the timeline
	if([self.timelineSlider nearEndOfTimeline:self.timelineSlider.value])
	{
		[self.timelineSlider expandTimeline];
		[self.keyframeView refreshAll];
		
		// TODO: We are just setting the duration to the size of the canvas
		// if we wanted to do this right, we'd probably set it to the time of the last keyframe
		// in any group, but then we would have to do that more often
		self.currentDocument.duration = [NSNumber numberWithFloat:self.timelineSlider.maximumValue];
	}
	
	
	if (self.isRecording)
	{
		[self.recordingSession transformAllGroupsByX:dX
												andY:dY
											rotation:dRotation
											   scale:dScale
											  atTime:self.timelineSlider.value];
	}
	else
	{

		SRTKeyframeType keyframeType =  self.isRecording ?
											SRTKeyframeTypeNone() :
											SRTKeyframeMake(isScaling, isRotating, isTranslating, NO);

		[self.rootGroup transformSelectionByX:dX
										 andY:dY
									 rotation:dRotation
										scale:dScale
								   visibility:YES
									   atTime:self.timelineSlider.value
							   addingKeyframe:keyframeType
						   usingInterpolation:YES];
	}
}

- (void)manipulatorDidStopInteraction:(id)sender
					  wasTranslating:(BOOL)isTranslating
						 wasRotating:(BOOL)isRotating
						  wasScaling:(BOOL)isScaling
						withDuration:(float)duration
{
	
	if(self.isRecording)
	{
		self.isRecording = NO;

		// Before we add our last keyframe, snap the timeline so our keyframe
		// will be easy to scrub to later
		[self snapTimeline:nil];


		[self.recordingSession finishAtTime:self.timelineSlider.value];
		
		// Stop playing
		[self setPlaying:NO];
		self.selectionOverlayButtons.recordPulsing = NO;
	}
	
	[self.rootGroup applyToSelectedSubTrees:^(PSDrawingGroup *g) {[g doneMutatingPositions];}];
	[PSDataModel save];
	
	[self refreshInterfaceAfterDataChange:YES selectionChange:YES];
}


/*
 ----------------------------------------------------------------------------
 PSPenColorChangeDelegate methods
 Called by when our pen colours change
 ----------------------------------------------------------------------------
 */
- (void)penColorChanged:(UIColor*)newColor
{
	self.currentColor = [PSHelpers colorToInt64:newColor];
	self.startDrawingButton.backgroundColor = newColor;
	[self startDrawing:nil];
	if(self.penPopoverController && self.penPopoverController.popoverVisible)
		[self.penPopoverController dismissPopoverAnimated:YES];
}

- (void)penWeightChanged:(int)newWeight
{
	self.penWeight = newWeight;
	[self startDrawing:nil];
	if(self.penPopoverController && self.penPopoverController.popoverVisible)
		[self.penPopoverController dismissPopoverAnimated:YES];
}


@end

