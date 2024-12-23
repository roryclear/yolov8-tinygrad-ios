#import <Foundation/Foundation.h>

CGFloat intersectionBetweenBox(NSArray *box1, NSArray *box2);
NSMutableDictionary<NSString *, id> *extractValues(NSString *x);
CGFloat unionBetweenBox(NSArray *box1, NSArray *box2);
CGFloat iouBetweenBox(NSArray *box1, NSArray *box2);
