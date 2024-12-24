#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

NS_ASSUME_NONNULL_BEGIN

@interface Yolo : NSObject

@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *pipeline_states;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *buffers;

// Initializer
- (instancetype)init;

- (CGFloat)intersectionBetweenBox:(NSArray *)box1 andBox:(NSArray *)box2;
- (CGFloat)unionBetweenBox:(NSArray *)box1 andBox:(NSArray *)box2;
- (CGFloat)iouBetweenBox:(NSArray *)box1 andBox:(NSArray *)box2;
- (NSMutableDictionary<NSString *, id> *)extractValues:(NSString *)x;

@end

NS_ASSUME_NONNULL_END
