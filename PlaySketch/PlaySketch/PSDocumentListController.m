/*
 
 --------------
 Copyright 2012 Singapore Management University
 
 This Source Code Form is subject to the terms of the
 Mozilla Public License, v. 2.0. If a copy of the MPL was
 not distributed with this file, You can obtain one at
 http://mozilla.org/MPL/2.0/.
 --------------
 
 */

#import "PSDocumentListController.h"
#import "PSDataModel.h"
#import "PSSceneViewController.h"
#import <QuartzCore/QuartzCore.h>

#define DOC_IMAGE_FRAME (CGRectMake(0, 0, 480.0, 270.0))
#define DOC_IMAGE_STEP 600.0
#define DOC_END_PADDING (1024.0 - DOC_IMAGE_STEP/2.0)
#define DOC_IMAGE_SNAP_XVALUE (1024.0 - (DOC_IMAGE_FRAME).size.width/2.0 - 20.0)
#define ANIMATION_DURATION 0.5
#define BACKGROUND_COLOR ([UIColor colorWithRed:1.000 green:0.977 blue:0.842 alpha:1.000])

/*
#define DOC_IMAGE_STEP_SIZE 650.0 // The pixel-distance between two buttons
#define ALLOWABLE_SELECTION_OFFSET 200 // The distance away from the center of a button that is still considered selected
*/

@interface PSDocumentListController ()
@property(nonatomic,retain)NSMutableArray* documentImages;
@property(nonatomic,retain)NSMutableArray* documents;
//@property(nonatomic,retain)UIButton* createDocumentButton;


//-(void)generateDocumentButtons;
//-(void)clearDocumentButtons;
//-(PSDrawingDocument*)selectedDocument:(CGFloat*)outPercentFromCentered;
//-(void)refreshSelectionAppearance;
//+(void)styleButton:(UIButton*)button;
- (void)createImageForDocumentAtIndex:(int)i;
- (void)scrollToIndex:(int)i animated:(BOOL)animated;
- (void)scrollToNearest:(BOOL)animated;
@end

@implementation PSDocumentListController
@synthesize scrollView = _scrollView;
@synthesize documents = _documents;
//@synthesize createDocumentButton = _newDocumentButton;
//@synthesize deleteButton = _deleteButton;
//@synthesize documentNameButton = _documentNameButton;


/*
	This is called after everything in the storyboard is loaded, but right
	before the view is shown on the screen.
	This is our chance to refresh the view's state before presenting it
*/
- (void)viewDidLoad
{
    [super viewDidLoad];
	
	//create our "new document" Button
/*	{
		CGRect defaultFrame = CGRectMake(281, 100, 462, 300);
		self.createDocumentButton = [[UIButton alloc] initWithFrame:defaultFrame];
		[self.createDocumentButton setTitle:@"Create New Animation" forState:UIControlStateNormal];
		[PSDocumentListController styleButton:self.createDocumentButton];
		[self.createDocumentButton addTarget:self action:@selector(newDocument:) forControlEvents:UIControlEventTouchUpInside];
		[self.scrollView addSubview:self.createDocumentButton];
	}
*/
	self.createDocButton.backgroundColor = BACKGROUND_COLOR;
	
	self.scrollView.delegate = self; //So we can respond to the scroll events
	NSLog(@"%lf, %lf", UIScrollViewDecelerationRateFast, UIScrollViewDecelerationRateNormal);
	self.scrollView.decelerationRate = UIScrollViewDecelerationRateFast;
	
	
	//Load up the existing documents
	self.documents = [NSMutableArray arrayWithArray:[PSDataModel allDrawingDocuments]];
	self.documentImages = [NSMutableArray arrayWithCapacity:self.documents.count];
	for (int i = 0; i < self.documents.count; i++)
		[self createImageForDocumentAtIndex:i];
	
	//TODO: scroll to where we last were!
	[self scrollToIndex:0 animated:NO];
}


- (void)createImageForDocumentAtIndex:(int)i
{
	PSDrawingDocument* doc = self.documents[i];
	UIImageView* b = [[UIImageView alloc] initWithFrame:DOC_IMAGE_FRAME];
	[self.scrollView addSubview:b];
	[self.documentImages addObject:b];
	
	b.backgroundColor = [UIColor redColor];
	b.center = CGPointMake( DOC_END_PADDING + DOC_IMAGE_STEP * (i + 0.5),
						   self.scrollView.frame.size.height/2.0 );

	//Give it an image for background
	NSData* imageData = doc.previewImage;
	if(imageData)
		b.image = [UIImage imageWithData:imageData];
	else
		b.backgroundColor = BACKGROUND_COLOR;

	//Make sure everything is in view
	CGSize newContentSize = self.scrollView.contentSize;
	newContentSize.width = self.documents.count*DOC_IMAGE_STEP + 2 * DOC_END_PADDING;
	self.scrollView.contentSize = newContentSize;
}

- (void)scrollToIndex:(int)i animated:(BOOL)animated
{
	CGPoint newOffset = self.scrollView.contentOffset;
	newOffset.x = DOC_END_PADDING + DOC_IMAGE_STEP * (i + 0.5) - DOC_IMAGE_SNAP_XVALUE;
	if(animated)
		[UIView animateWithDuration:ANIMATION_DURATION
						 animations:^{self.scrollView.contentOffset = newOffset;}];
	else
		self.scrollView.contentOffset = newOffset;
		
}

- (void)scrollToNearest:(BOOL)animated
{
	// Snap back to where we belong!
	// First calculate the index of the document nearest where we are
	CGFloat currentXValueOffset = self.scrollView.contentOffset.x + DOC_IMAGE_SNAP_XVALUE;
	CGFloat floatIndex = (currentXValueOffset - DOC_END_PADDING) / DOC_IMAGE_STEP - 0.5;
	int requestedIndex = round(floatIndex);
	requestedIndex = MAX(0, requestedIndex);
	requestedIndex = MIN(requestedIndex, self.documents.count - 1);
	
	// Then scroll there!
	[self scrollToIndex:requestedIndex animated:animated];
}

/*
	This is called right after the view has left the screen. 
	It gives us the opportunity to free any resources the view was using.
	Its actions should be symmetrical to viewDidLoad
*/
- (void)viewDidUnload
{
	[super viewDidUnload];
/*	[self clearDocumentButtons];
	[self.createDocumentButton removeFromSuperview];
	self.createDocumentButton = nil;
*/
}


-(void) viewWillAppear:(BOOL)animated
{
//	[self generateDocumentButtons];
//	[self refreshSelectionAppearance];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return UIInterfaceOrientationIsLandscape(interfaceOrientation);
}




//-(void)generateDocumentButtons
//{
	/*
	if(self.documentButtons != nil)
		[self clearDocumentButtons];
	
	
	// Fetch a list of all the documents
	self.documentRoots = [PSDataModel allDrawingDocuments];
	NSMutableArray* buttons = [NSMutableArray arrayWithCapacity:self.documentRoots.count];
	
	// Set up some size variables for doing the layout of the buttons
	CGRect buttonFrame = CGRectMake(0, 0, 462, 300);
	CGFloat centerX =  self.scrollView.frame.size.width/2.0;

	// Give the scrollview's scrolling area the right size to hold them all
	// This means DOC_BUTTON_STEP_SIZE for each document + padding at the start and end to be able to center
	CGSize newContentSize = self.scrollView.contentSize;
	newContentSize.width = (self.documentRoots.count + 1)*DOC_BUTTON_STEP_SIZE +
							2 * (self.scrollView.frame.size.width/2.0 - DOC_BUTTON_STEP_SIZE/2.0);
	self.scrollView.contentSize = newContentSize;

	// Create a button for each document and add to the scroll view
	
	for(PSDrawingDocument* docRoot in self.documentRoots)
	{
		UIButton* docButton = [[UIButton alloc] initWithFrame:buttonFrame];
		[PSDocumentListController styleButton:docButton];

		[self.scrollView addSubview:docButton];
		docButton.center = CGPointMake(centerX, self.scrollView.bounds.size.height/2.0);		
		
		//Hook up the button to call viewDocument:
		[docButton addTarget:self action:@selector(viewDocument:) forControlEvents:UIControlEventTouchUpInside];

		//Put the background image in the button
		
		
		[buttons addObject:docButton];		

		centerX += DOC_BUTTON_STEP_SIZE;
	}

	//Set the create document button to align properly
	[UIView beginAnimations:@"create document button" context:nil];
	self.createDocumentButton.center = CGPointMake(centerX, self.scrollView.bounds.size.height/2.0);
	[UIView commitAnimations];
	
	self.documentButtons = buttons;
*/
//}


//-(void)clearDocumentButtons
//{
	/*
	for(UIButton* button in self.documentButtons)
	{
		[button removeFromSuperview];
	}
	self.documentButtons = nil;
	self.documentRoots = nil;
	self.scrollView.contentSize = self.scrollView.frame.size;
	*/
	
//}


/*
	We will consider the document nearest to being centered in the view to be "selected", 
	but only if it falls within ALLOWABLE_SELECTION_OFFSET of being perfectly centered.
	outPercentFromCentered is an optional argument to return how close we are to centered.
	1.0 means perfectly centred, 0.0 means off by ALLOWABLE_SELECTION_OFFSET
*/
/*
-(PSDrawingDocument*)selectedDocument:(CGFloat*)outPercentFromCentered
{
	// Get the document that is nearest the center of the scrollview
	int currentIndex = round(self.scrollView.contentOffset.x/DOC_BUTTON_STEP_SIZE);
	currentIndex = MAX(currentIndex, 0);
	currentIndex = MIN(currentIndex, self.documentButtons.count - 1);
	
	//Calculate the percentFromCenetered
	CGFloat idealOffsetX = currentIndex * DOC_BUTTON_STEP_SIZE;
	CGFloat percentFromCentered = 1 - fabs(idealOffsetX - self.scrollView.contentOffset.x)/
									ALLOWABLE_SELECTION_OFFSET;
	if ( outPercentFromCentered )
		*outPercentFromCentered = MAX( 0, percentFromCentered );
	
	// Return the document if we are close enough
	if ( currentIndex < self.documentRoots.count && percentFromCentered > 0 )
		return [self.documentRoots objectAtIndex:currentIndex];
	else
		return nil;
}
*/

-(IBAction)newDocument:(id)sender
{
	NSString* newDocName = [NSString stringWithFormat:@"Untitled Animation %d",
							[PSDataModel allDrawingDocuments].count + 1];
	PSDrawingDocument* newDocument = [PSDataModel newDrawingDocumentWithName:newDocName];

	//Scroll to the last item
	[self scrollToIndex:self.documents.count animated:YES];
	
	// Add it to the list and create a button
	[self.documents addObject:newDocument];
	[self createImageForDocumentAtIndex:self.documents.count - 1];
	
	//Animate the appearance of the button
	UIImageView* newImage = self.documentImages[self.documentImages.count - 1];
	CGRect destinationFrame = newImage.frame;
	CGRect startFrame = [self.scrollView convertRect:self.createDocButton.frame
											fromView:self.createDocButton.superview];
	newImage.frame = startFrame;
	newImage.alpha = 0.0;
	[UIView animateWithDuration:ANIMATION_DURATION
						  delay:ANIMATION_DURATION
						options:0
					 animations:^{	newImage.frame = destinationFrame;
									newImage.alpha = 1.0;}
					 completion:nil];

	
	
	/*


//	[PSDataModel DEBUG_generateTestShapesIntoGroup:newDocument.rootGroup];
//	[PSDataModel DEBUG_generateRandomLittleLinesIntoGroup:newDocument.rootGroup lineCount:100];
	[self performSegueWithIdentifier:@"GoToSceneViewController" sender:newDocument];
	 */
}
/*

-(IBAction)deleteDocument:(id)sender
{
	PSDrawingDocument* docToDelete = [self selectedDocument:nil];
	if ( docToDelete )
	{
		//Delete it
		CGPoint offsetBeforeDeleting = self.scrollView.contentOffset;
		[PSDataModel deleteDrawingDocument:docToDelete];
		
		//Reload our data
		[self generateDocumentButtons];
		
		// TODO: animate the delete better
		
		// Trigger an update of our labels
		self.scrollView.contentOffset = offsetBeforeDeleting;
		[self refreshSelectionAppearance];
		
	}
}
 */


/*
	Show the document that corresponds to senderButton
	Do this by looking up the document that corresponds to the button clicked,
	then triggering the "GoToSceneViewController segue in the storyboard
*/
/*
-(void)viewDocument:(id)senderButton
{
	// Find the index of the document that corresponds to this button
	int index = [self.documentButtons indexOfObject:senderButton];
	
	if ( index >= 0 && index < self.documentRoots.count)
	{
		// Call the segue from the storyboard
		PSDrawingDocument* document = [self.documentRoots objectAtIndex:index];
		[self performSegueWithIdentifier:@"GoToSceneViewController" sender:document];

		[self refreshSelectionAppearance];
	}
}
*/

/*
	Called by the button on the document name, to start renaming the selected document
*/
/*
-(IBAction)startRenameDocument:(id)sender
{
	UIAlertView *alertView = [[UIAlertView alloc] 
							  initWithTitle:@"Rename Animation"
							  message:@"Enter a new name"
							  delegate:self
							  cancelButtonTitle:@"Cancel" 
							  otherButtonTitles:@"OK", nil];
	alertView.alertViewStyle = UIAlertViewStylePlainTextInput;
	[alertView show];
}
*/

/*
	UIAlertView delegate method
	This is called when an alertview is dismissed by the user.
	The only alertview that is being used here is for renaming a document
*/
/*
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	if ( buttonIndex > 0 )
	{
		NSString* newName = [alertView textFieldAtIndex:0].text;
		PSDrawingDocument* document = [self selectedDocument:nil];
		
		if (newName && newName.length > 0 && document )
		{
			document.name = newName;
			[PSDataModel save];
			[self refreshSelectionAppearance];
		}
	}
}
*/

/*
	This is called automatically each time we segue away from this view
	We can tell which segue triggered this call by looking at [segue identifier]
*/
/*
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{

	// Check if this is the segue where we are loading up a scene
	// We are passing the document in as the sender in viewDocument:
    if ( [[segue identifier] isEqualToString:@"GoToSceneViewController"]
		&& [sender class] == [PSDrawingDocument class] )
    {
		//Set the root scene view controller from the supplied document
		PSSceneViewController *vc = [segue destinationViewController];
		vc.currentDocument = (PSDrawingDocument*)sender;
		vc.rootGroup = ((PSDrawingDocument*)sender).rootGroup;
    }
}
*/


/*
	Scrollview delegate methods
	Implementing these let this controller respond to changes in the scrollview,
	to keep us centred on a button
*/
//- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
	[self scrollToNearest:YES];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
	if(decelerate == YES) return;

	[self scrollToNearest:YES];
}


-(void)scrollViewDidScroll:(UIScrollView *)scrollView
{
	CGFloat currentXValueOffset = self.scrollView.contentOffset.x + DOC_IMAGE_SNAP_XVALUE;
	CGFloat floatIndex = (currentXValueOffset - DOC_END_PADDING) / DOC_IMAGE_STEP - 0.5;
	CGFloat pcntOff = fabsf(floatIndex - round(floatIndex))*2.0; // 0 = hit, 1 = miss
	int index = round(floatIndex);
	NSLog(@"index: %d, %lf", index, pcntOff);
	if(index < 0 || index >= self.documents.count)
		self.docButtonsContainer.alpha = 0.0;
	else
		self.docButtonsContainer.alpha = MAX(1.0 - pcntOff*2.0, 0); // compress the scale
	
}


/*
	Update the label and delete button to fade unless the document is directly
	above them
 */
/*
-(void)refreshSelectionAppearance
{
	CGFloat percentFromCentered;
	PSDrawingDocument* currentDocument = [self selectedDocument:&percentFromCentered];
	
	if (currentDocument)
	{
		//Fade our labels according to percentFromCentered
		[self.documentNameButton setTitle:currentDocument.name forState:UIControlStateNormal];
		self.documentNameButton.alpha = percentFromCentered;
		self.documentNameButton.enabled = YES;
		self.deleteButton.alpha = percentFromCentered;
		self.deleteButton.enabled = percentFromCentered;
	}
	else
	{
		//Hide everything
		self.documentNameButton.alpha = 0.0;
		self.documentNameButton.enabled = NO;
		self.deleteButton.alpha = 0;
		self.deleteButton.enabled = NO;
	}	
}
*/
/*
+(void)styleButton:(UIButton*)button
{
	[button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
	button.layer.shadowColor = [UIColor blackColor].CGColor;
	button.layer.shadowOffset = CGSizeMake(0, 10);
	button.layer.shadowRadius = 10.0;
	button.layer.shadowOpacity = 0.8;
	button.layer.shouldRasterize = YES;
}
*/

@end
