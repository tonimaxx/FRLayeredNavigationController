/*     This file is part of FancyVC.
 *
 * FancyVC is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * FancyVC is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with FancyVC.  If not, see <http://www.gnu.org/licenses/>.
 *
 *
 *  Copyright (c) 2012, Johannes Weiß <weiss@tux4u.de> for factis research GmbH.
 */

#import "FancyNavigationController.h"
#import "FancyChromeController.h"

#import <QuartzCore/QuartzCore.h>

@interface FancyNavigationController ()

@end

@implementation FancyNavigationController

#pragma mark - Initialization
- (id)initWithRootViewController:(UIViewController *)rootViewController
{
    self = [super init];
    if (self) {
        self->viewControllers = [[NSMutableArray alloc] initWithObjects:rootViewController, nil];
    }
    return self;    
}


#pragma mark - UIViewController interface

- (void)loadView
{
    NSAssert([self->viewControllers count] == 1, @"This is a bug, more than one ViewController present! Go on and implement more sophisticated view loading/unloading...");
    UIViewController *rootViewController = [self->viewControllers objectAtIndex:0];
    [self addChildViewController:rootViewController];
    
    self.view = [[UIView alloc] init];
    CGRect rootViewFrame = CGRectMake(0, 0, 400, self.view.bounds.size.height);
    rootViewController.view.frame = rootViewFrame;
    rootViewController.view.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:rootViewController.view];
    [rootViewController didMoveToParentViewController:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIPanGestureRecognizer *panGR = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                            action:@selector(handleGesture:)];
    panGR.maximumNumberOfTouches = 1;
    [self.view addGestureRecognizer:panGR];
    
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *path = [bundle pathForResource:@"steel" ofType:@"png"];
    self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageWithContentsOfFile:path]];
}

- (void)viewWillLayoutSubviews
{
    NSInteger i = 0;
    for (UIViewController *vc in self->viewControllers) {
        FancyChromeController *fvc = nil;
        if ([vc class] == [FancyChromeController class]) {
            fvc = (FancyChromeController *)vc;
        }
        CGRect oldFrame = vc.view.frame;
        const CGFloat newX = fvc == nil ? 0 : fvc.fancyNavigationItem.currentViewPosition.x;
        CGRect newFrame = CGRectMake(newX,
                                     fvc == nil ? 0 : fvc.fancyNavigationItem.currentViewPosition.y,
                                     fvc.leaf ? self.view.bounds.size.width - newX : oldFrame.size.width,
                                     self.view.bounds.size.height);
        [UIView animateWithDuration:0.3 animations:^{
            vc.view.frame = newFrame;
        }];
        i++;
    }
    return;
}

- (void)viewWillUnload
{
    NSAssert([self->viewControllers count] == 1, @"This is a bug, more than one ViewController present! Go on and implement more sophisticated view loading/unloading...");
}

- (void)viewDidUnload
{
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

#pragma mark - UIGestureRecognizer delegate interface

- (void)handleGesture:(UIPanGestureRecognizer *)gestureRecognizer
{
    switch (gestureRecognizer.state) {
        case UIGestureRecognizerStatePossible: {
            //NSLog(@"UIGestureRecognizerStatePossible");
            break;
        }
            
        case UIGestureRecognizerStateBegan: {
            //NSLog(@"UIGestureRecognizerStateBegan");
            break;
        }
            
        case UIGestureRecognizerStateChanged: {
            //NSLog(@"UIGestureRecognizerStateChanged, vel=%f", [gestureRecognizer velocityInView:firstView].x);
            
            const NSInteger startVcIdx = [self->viewControllers count]-1;
            const UIViewController *startVc = [self->viewControllers objectAtIndex:startVcIdx];
            
            [self moveViewControllerIndex:startVcIdx
                    withGestureRecognizer:gestureRecognizer
                          withParentIndex:-1
                       parentLastPosition:CGPointZero
                      descendentOfTouched:NO];
            [gestureRecognizer setTranslation:CGPointZero inView:startVc.view];
            break;
        }
            
        case UIGestureRecognizerStateEnded: {
            //NSLog(@"UIGestureRecognizerStateEnded");
            [UIView animateWithDuration:0.2 animations:^{
                [self moveToSnappingPointsWithGestureRecognizer:gestureRecognizer];
            }];
            
            break;
        }
            
        default:
            break;
    }
}

#pragma mark - internal methods

- (void)moveToSnappingPointsWithGestureRecognizer:(UIPanGestureRecognizer *)g
{
    FancyChromeController *last = nil;
    CGFloat xTranslation = 0;
    
    for (FancyChromeController *vc in self->viewControllers) {
        const CGPoint myPos = vc.view.frame.origin;
        const CGPoint myInitPos = vc.fancyNavigationItem.initialViewPosition;
        const CGSize mySize = vc.view.frame.size;
        
        const CGFloat curDiff = myPos.x - last.view.frame.origin.x;
        const CGFloat initDiff = myInitPos.x - last.fancyNavigationItem.initialViewPosition.x;
        const CGFloat maxDiff = last.view.frame.size.width;
                
        if (xTranslation == 0 && (curDiff != initDiff && curDiff != maxDiff)) {
            if ([g velocityInView:vc.view].x > 0) {
                xTranslation = maxDiff - curDiff;
            } else {
                xTranslation = initDiff - curDiff;
                
            }
        }
        
        vc.view.frame = CGRectMake(myPos.x + xTranslation, myPos.y, mySize.width, mySize.height);
        last = vc;
        vc.fancyNavigationItem.currentViewPosition = CGPointMake(vc.view.frame.origin.x, vc.view.frame.origin.y);
    }
}

- (void)moveViewControllerIndex:(NSInteger)myIndex
          withGestureRecognizer:(UIPanGestureRecognizer *)g
                withParentIndex:(NSInteger)parentIndex
             parentLastPosition:(CGPoint)parentOldPos
            descendentOfTouched:(BOOL)descendentOfTouched
{
    if (myIndex == 0) {
        return;
    }
    
    const FancyChromeController *me = [self.viewControllers objectAtIndex:myIndex];
    const FancyChromeController *parent = parentIndex < 0 ? nil : [self.viewControllers objectAtIndex:myIndex+1];
    
    const CGPoint myPos = me.view.frame.origin;
    const CGPoint parentPos = parent.view.frame.origin;
    const CGSize mySize = me.view.frame.size;
    const CGPoint myInitPos = me.fancyNavigationItem.initialViewPosition;
    const CGPoint parentInitPos = parent.fancyNavigationItem.initialViewPosition;
    
    const CGFloat myWidth = mySize.width;
    
    const CGPoint myOldPos = myPos;
    
    CGPoint myNewPos = myPos;
    
    if (parentIndex < 0 || !descendentOfTouched) {
        CGPoint touchTranslation = [g translationInView:me.view];
        CGPoint translation;
        if (myPos.x + touchTranslation.x < me.fancyNavigationItem.initialViewPosition.x) {
            translation = CGPointMake(touchTranslation.x / 2, 0);
        } else {
            translation = touchTranslation;
        }
        myNewPos = CGPointMake(myPos.x + translation.x, myPos.y);
    } else {
        const CGFloat minDiff = parentInitPos.x - myInitPos.x;
        
        if (parentOldPos.x >= myPos.x + myWidth || parentPos.x >= myPos.x + myWidth) {
            /* if snapped to parent's right border, move with parent */
            myNewPos = CGPointMake(parentPos.x - myWidth, myPos.y);
        }

        if (parentPos.x - myNewPos.x <= minDiff) {
            /* at least minDiff difference between parent and me */
            myNewPos = CGPointMake(parentPos.x - minDiff, myPos.y);
            
        }
    }
    
    if (parentIndex >= 0 && myNewPos.x < myInitPos.x) {
        /* don't move past the left snapping point */
        myNewPos = myInitPos;
    }
    
    me.view.frame = CGRectMake(myNewPos.x, myNewPos.y, mySize.width, mySize.height);
    
    UIView *touchedView = [g.view hitTest:[g locationInView:g.view] withEvent:nil];
    
    if (!descendentOfTouched && [touchedView isDescendantOfView:me.view]) {
        [self moveViewControllerIndex:myIndex-1
                withGestureRecognizer:g
                      withParentIndex:myIndex
                   parentLastPosition:myOldPos
                  descendentOfTouched:YES];
    } else {
        [self moveViewControllerIndex:myIndex-1
                withGestureRecognizer:g 
                      withParentIndex:myIndex
                   parentLastPosition:myOldPos
                  descendentOfTouched:descendentOfTouched];
    }
}


- (void)compactViewPositions
{
    for (UIViewController *vc in self->viewControllers) {
        if ([vc class] == [FancyChromeController class]) {
            FancyChromeController *fvc = (FancyChromeController *)vc;
            fvc.fancyNavigationItem.currentViewPosition = fvc.fancyNavigationItem.initialViewPosition;
        }
    }
}


#pragma mark - Public API

- (void)popViewControllerAnimated:(BOOL)animated
{
    UIViewController *vc = [self->viewControllers lastObject];
    
    [vc willMoveToParentViewController:nil];
    [self->viewControllers removeObject:vc];
    
    CGRect goAwayFrame = CGRectMake(vc.view.frame.origin.x, 1024, vc.view.frame.size.width, vc.view.frame.size.height);
    [UIView animateWithDuration:animated ? 0.5 : 0
                          delay:0
                        options: UIViewAnimationCurveLinear
                     animations:^{
                         vc.view.frame = goAwayFrame;
                     }
                     completion:^(BOOL finished) {
                         [vc.view removeFromSuperview];
                         [vc removeFromParentViewController];  
                     }];
}

- (void)popToViewController:(UIViewController *)vc animated:(BOOL)animated
{
    UIViewController *currentVc;

    while ((currentVc = [self->viewControllers lastObject])) {
        if (([currentVc class] == [FancyChromeController class] &&
             ((FancyChromeController*)currentVc).contentViewController == vc) ||
            ([currentVc class] != [FancyChromeController class] &&
             currentVc == vc)) {
                break;
            }
        
        [self popViewControllerAnimated:animated];
    }
}

- (void)popToRootViewControllerAnimated:(BOOL)animated
{
    [self popToViewController:[self->viewControllers objectAtIndex:0] animated:animated];
}

- (void)pushViewController:(UIViewController *)contentViewController
                 inFrontOf:(UIViewController *)anchorViewController
              maximumWidth:(BOOL)maxWidth
                  animated:(BOOL)animated
             configuration:(void (^)(FancyNavigationItem *item))configuration
{
    FancyChromeController *viewController = [[FancyChromeController alloc]
                                        initWithContentViewController:contentViewController leaf:maxWidth];
    
    [self popToViewController:anchorViewController animated:animated];
    
    NSUInteger vcCount = [self->viewControllers count];

    CGRect startFrame = CGRectMake(1024,
                                   0,
                                   viewController.leaf ? self.view.bounds.size.width - vcCount * 44 : 400,
                                   self.view.bounds.size.height);
    
    viewController.fancyNavigationItem.initialViewPosition = CGPointMake(vcCount * 44, 0);
    viewController.fancyNavigationItem.currentViewPosition = viewController.fancyNavigationItem.initialViewPosition;
    
    configuration(viewController.fancyNavigationItem);
    
    CGRect newFrame = CGRectMake(viewController.fancyNavigationItem.initialViewPosition.x,
                                 viewController.fancyNavigationItem.initialViewPosition.y,
                                 startFrame.size.width,
                                 startFrame.size.height);
    
    [self->viewControllers addObject:viewController];
    
    NSAssert(self.parentViewController == nil, @"NavVC.parent != nil");
    NSAssert(viewController.parentViewController == nil, @"VC.parent != nil");
    NSAssert([self class] == [FancyNavigationController class], @"NavVC wrong class");
    NSAssert([viewController class] == [FancyChromeController class], @"VC wrong class");

    [self addChildViewController:viewController];
    
    viewController.view.frame = startFrame;
    
    [self.view addSubview:viewController.view];
    [viewController didMoveToParentViewController:self];
    
    [UIView animateWithDuration:animated ? 0.5 : 0
                          delay:0
                        options: UIViewAnimationCurveEaseOut
                     animations:^{
                         viewController.view.frame = newFrame;
                     }
                     completion:^(BOOL finished) {
                     }];
    [self compactViewPositions];
    [self.view setNeedsLayout];
}

- (void)pushViewController:(UIViewController *)contentViewController
                 inFrontOf:(UIViewController *)anchorViewController
              maximumWidth:(BOOL)maxWidth
                  animated:(BOOL)animated
{
    [self pushViewController:contentViewController
                   inFrontOf:anchorViewController
                maximumWidth:maxWidth
                    animated:animated
               configuration:^(FancyNavigationItem *item) {
               }];
}

#pragma mark - properties

@synthesize viewControllers;

@end
