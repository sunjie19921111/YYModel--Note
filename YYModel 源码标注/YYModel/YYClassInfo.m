//
//  YYClassInfo.m
//  YYKit <https://github.com/ibireme/YYKit>
//
//  Created by ibireme on 15/5/9.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#
#import "YYClassInfo.h"
#import <objc/runtime.h>

YYEncodingType YYEncodingGetType(const char *typeEncoding) {
    char *type = (char *)typeEncoding;
    if (!type) return YYEncodingTypeUnknown;
    size_t len = strlen(type);
    if (len == 0) return YYEncodingTypeUnknown;
    
    YYEncodingType qualifier = 0;
    bool prefix = true;
    while (prefix) {
        switch (*type) {
            case 'r': {
                qualifier |= YYEncodingTypeQualifierConst;
                type++;
            } break;
            case 'n': {
                qualifier |= YYEncodingTypeQualifierIn;
                type++;
            } break;
            case 'N': {
                qualifier |= YYEncodingTypeQualifierInout;
                type++;
            } break;
            case 'o': {
                qualifier |= YYEncodingTypeQualifierOut;
                type++;
            } break;
            case 'O': {
                qualifier |= YYEncodingTypeQualifierBycopy;
                type++;
            } break;
            case 'R': {
                qualifier |= YYEncodingTypeQualifierByref;
                type++;
            } break;
            case 'V': {
                qualifier |= YYEncodingTypeQualifierOneway;
                type++;
            } break;
            default: { prefix = false; } break;
        }
    }

    len = strlen(type);
    if (len == 0) return YYEncodingTypeUnknown | qualifier;

    switch (*type) {
        case 'v': return YYEncodingTypeVoid | qualifier;
        case 'B': return YYEncodingTypeBool | qualifier;
        case 'c': return YYEncodingTypeInt8 | qualifier;
        case 'C': return YYEncodingTypeUInt8 | qualifier;
        case 's': return YYEncodingTypeInt16 | qualifier;
        case 'S': return YYEncodingTypeUInt16 | qualifier;
        case 'i': return YYEncodingTypeInt32 | qualifier;
        case 'I': return YYEncodingTypeUInt32 | qualifier;
        case 'l': return YYEncodingTypeInt32 | qualifier;
        case 'L': return YYEncodingTypeUInt32 | qualifier;
        case 'q': return YYEncodingTypeInt64 | qualifier;
        case 'Q': return YYEncodingTypeUInt64 | qualifier;
        case 'f': return YYEncodingTypeFloat | qualifier;
        case 'd': return YYEncodingTypeDouble | qualifier;
        case 'D': return YYEncodingTypeLongDouble | qualifier;
        case '#': return YYEncodingTypeClass | qualifier;
        case ':': return YYEncodingTypeSEL | qualifier;
        case '*': return YYEncodingTypeCString | qualifier;
        case '^': return YYEncodingTypePointer | qualifier;
        case '[': return YYEncodingTypeCArray | qualifier;
        case '(': return YYEncodingTypeUnion | qualifier;
        case '{': return YYEncodingTypeStruct | qualifier;
        case '@': {
            if (len == 2 && *(type + 1) == '?')
                return YYEncodingTypeBlock | qualifier;
            else
                return YYEncodingTypeObject | qualifier;
        }
        default: return YYEncodingTypeUnknown | qualifier;
    }
}

@implementation YYClassIvarInfo

- (instancetype)initWithIvar:(Ivar)ivar {
    if (!ivar) return nil;
    self = [super init];
    _ivar = ivar;
    const char *name = ivar_getName(ivar);
    if (name) {
        _name = [NSString stringWithUTF8String:name];
    }
    _offset = ivar_getOffset(ivar);
    const char *typeEncoding = ivar_getTypeEncoding(ivar);
    if (typeEncoding) {
        _typeEncoding = [NSString stringWithUTF8String:typeEncoding];
        _type = YYEncodingGetType(typeEncoding);
    }
    return self;
}

@end

@implementation YYClassMethodInfo

- (instancetype)initWithMethod:(Method)method {
    NSLog(@"initWithMethod:(Method)method");
    if (!method) return nil;
    self = [super init];
    _method = method;
    _sel = method_getName(method);
    _imp = method_getImplementation(method);
    const char *name = sel_getName(_sel);
    if (name) {
        _name = [NSString stringWithUTF8String:name];
    }
    
    const char *typeEncoding = method_getTypeEncoding(method);
    if (typeEncoding) {
        _typeEncoding = [NSString stringWithUTF8String:typeEncoding];
    }
    char *returnType = method_copyReturnType(method);
    if (returnType) {
        _returnTypeEncoding = [NSString stringWithUTF8String:returnType];
        free(returnType);
    }
    unsigned int argumentCount = method_getNumberOfArguments(method);
    if (argumentCount > 0) {
        NSMutableArray *argumentTypes = [NSMutableArray new];
        for (unsigned int i = 0; i < argumentCount; i++) {
            char *argumentType = method_copyArgumentType(method, i);
            NSString *type = argumentType ? [NSString stringWithUTF8String:argumentType] : nil;
            [argumentTypes addObject:type ? type : @""];
            if (argumentType) free(argumentType);
        }
        _argumentTypeEncodings = argumentTypes;
    }
    return self;
}

@end

@implementation YYClassPropertyInfo

- (instancetype)initWithProperty:(objc_property_t)property {
    NSLog(@"initWithProperty:(objc_property_t)property");
    if (!property) return nil;
    self = [super init];
    _property = property;
    const char *name = property_getName(property);
    if (name) {
        _name = [NSString stringWithUTF8String:name];
    }
    
    //objc_property_attribute_t 是什么东西可以到这里去看http://blog.csdn.net/sunjie886/article/details/61914594
    YYEncodingType type = 0;
    unsigned int attrCount;
    objc_property_attribute_t *attrs = property_copyAttributeList(property, &attrCount);
    for (unsigned int i = 0; i < attrCount; i++) {
        switch (attrs[i].name[0]) {
            case 'T': { // Type encoding
                if (attrs[i].value) {
                    _typeEncoding = [NSString stringWithUTF8String:attrs[i].value];
                    type = YYEncodingGetType(attrs[i].value);
                    
                    if ((type & YYEncodingTypeMask) == YYEncodingTypeObject && _typeEncoding.length) {
                        NSScanner *scanner = [NSScanner scannerWithString:_typeEncoding];
                        if (![scanner scanString:@"@\"" intoString:NULL]) continue;
                        
                        NSString *clsName = nil;
                        if ([scanner scanUpToCharactersFromSet: [NSCharacterSet characterSetWithCharactersInString:@"\"<"] intoString:&clsName]) {
                            if (clsName.length) _cls = objc_getClass(clsName.UTF8String);
                        }
                        
                        NSMutableArray *protocols = nil;
                        while ([scanner scanString:@"<" intoString:NULL]) {
                            NSString* protocol = nil;
                            if ([scanner scanUpToString:@">" intoString: &protocol]) {
                                if (protocol.length) {
                                    if (!protocols) protocols = [NSMutableArray new];
                                    [protocols addObject:protocol];
                                }
                            }
                            [scanner scanString:@">" intoString:NULL];
                        }
                        _protocols = protocols;
                    }
                }
            } break;
            case 'V': { // Instance variable
                if (attrs[i].value) {
                    _ivarName = [NSString stringWithUTF8String:attrs[i].value];
                }
            } break;
            case 'R': {
                type |= YYEncodingTypePropertyReadonly;
            } break;
            case 'C': {
                type |= YYEncodingTypePropertyCopy;
            } break;
            case '&': {
                type |= YYEncodingTypePropertyRetain;
            } break;
            case 'N': {
                type |= YYEncodingTypePropertyNonatomic;
            } break;
            case 'D': {
                type |= YYEncodingTypePropertyDynamic;
            } break;
            case 'W': {
                type |= YYEncodingTypePropertyWeak;
            } break;
            case 'G': {
                type |= YYEncodingTypePropertyCustomGetter;
                if (attrs[i].value) {
                    _getter = NSSelectorFromString([NSString stringWithUTF8String:attrs[i].value]);
                }
            } break;
            case 'S': {
                type |= YYEncodingTypePropertyCustomSetter;
                if (attrs[i].value) {
                    _setter = NSSelectorFromString([NSString stringWithUTF8String:attrs[i].value]);
                }
            }
            default: break;
        }
    }
    
    if (attrs) {
        free(attrs);
        attrs = NULL;
    }
    _type = type;
    if (_name.length) {
        if (!_getter) {
            //SEL 我感觉就是这么个意思了，有不同意思的请留言
            //SEL就是对方法的一种包装。包装的SEL类型数据它对应相应的方法地址，找到方法地址就可以调用方法
            // 方法的存储位置
            //在内存中每个类的方法都存储在类对象中
            //每个方法都有一个与之对应的SEL类型的数据
            // 根据一个SEL数据就可以找到对应的方法地址，进而调用方法
            // SEL类型的定义:  typedef struct objc_selector *SEL
            //更多详情请到http://blog.csdn.net/sunjie886/article/details/61914996
            _getter = NSSelectorFromString(_name);
        }
        //同上
        if (!_setter) {
            _setter = NSSelectorFromString([NSString stringWithFormat:@"set%@%@:", [_name substringToIndex:1].uppercaseString, [_name substringFromIndex:1]]);
        }
    }
    return self;
}

@end

@implementation YYClassInfo {
    BOOL _needUpdate;
}

- (instancetype)initWithClass:(Class)cls {
   //这里看的东西先看一篇文章容易理解 http://blog.csdn.net/sunjie886/article/details/61918905
    if (!cls) return nil;
    self = [super init];
    _cls = cls;
    _superCls = class_getSuperclass(cls);
    _isMeta = class_isMetaClass(cls);
    if (!_isMeta) {
        _metaCls = objc_getMetaClass(class_getName(cls));
    }
    _name = NSStringFromClass(cls);
    [self _update];

    _superClassInfo = [self.class classInfoWithClass:_superCls];
    return self;
}

- (void)_update {
    //初始化
    _ivarInfos = nil;
    _methodInfos = nil;
    _propertyInfos = nil;
     //Class的转化：1　　　　　Class　变量名　=　[类或者对象　class];
    // 2　Class　变量名　=　[类或者对象　superclass];
    //3　 Class　变量名　=　NSClassFromString(方法名字的字符串);
    //4　 NSString　*变量名　=　NSStringFromClass(Class参数);
    //更多的详情，请到http://blog.csdn.net/sunjie886/article/details/61915135
    Class cls = self.cls;
    unsigned int methodCount = 0;
    //得到所有类中所有的方法
    /*
    @interface YYClassMethodInfo : NSObject
    @property (nonatomic, assign, readonly) Method method;                  ///< 结构体
    @property (nonatomic, strong, readonly) NSString *name;                 ///< 名字
    @property (nonatomic, assign, readonly) SEL sel;                        ///< method's selector
    @property (nonatomic, assign, readonly) IMP imp;                        ///< method's implementation
    @property (nonatomic, strong, readonly) NSString *typeEncoding;         ///< method's parameter and return types
    @property (nonatomic, strong, readonly) NSString *returnTypeEncoding;   ///< return value's type
    @property (nullable, nonatomic, strong, readonly) NSArray<NSString *> *argumentTypeEncodings; ///< array of
    @end  */
 
    Method *methods = class_copyMethodList(cls, &methodCount);
    if (methods) {
        NSMutableDictionary *methodInfos = [NSMutableDictionary new];
        _methodInfos = methodInfos;
        for (unsigned int i = 0; i < methodCount; i++) {
            //取出方法题的属性YYClassMethodInfo
            YYClassMethodInfo *info = [[YYClassMethodInfo alloc] initWithMethod:methods[i]];
            
            if (info.name) methodInfos[info.name] = info;
        }
        free(methods);
    }
    
    unsigned int propertyCount = 0;
    //得到类中所有的属性
    /*
    @interface YYClassPropertyInfo : NSObject
    @property (nonatomic, assign, readonly) objc_property_t property; ///< 结构体
    @property (nonatomic, strong, readonly) NSString *name;           ///< 名字
    @property (nonatomic, assign, readonly) YYEncodingType type;      ///< 类型
    @property (nonatomic, strong, readonly) NSString *typeEncoding;   ///< 编码
    @property (nonatomic, strong, readonly) NSString *ivarName;       ///< 变量的名字
    @property (nullable, nonatomic, assign, readonly) Class cls;      ///< 类
    @property (nullable, nonatomic, strong, readonly) NSArray<NSString *> *protocols; ///<协议
    @property (nonatomic, assign, readonly) SEL getter;               ///< getter
    @property (nonatomic, assign, readonly) SEL setter;               ///< setter 
    */
    objc_property_t *properties = class_copyPropertyList(cls, &propertyCount);
    if (properties) {
        NSMutableDictionary *propertyInfos = [NSMutableDictionary new];
        _propertyInfos = propertyInfos;
        for (unsigned int i = 0; i < propertyCount; i++) {
            ////取出属性的属性YYClassMethodInfo
            YYClassPropertyInfo *info = [[YYClassPropertyInfo alloc] initWithProperty:properties[i]];
            if (info.name) propertyInfos[info.name] = info;
        }
        free(properties);
    }
    
    //取出所有的变量 ptrdiff_t 这个应该牵扯到一个数据宽度的问题，不知道对不对 我猜的 官方解释：ptrdiff_t类型变量通常用来保存两个指针减法操作的结果
    /*  
     @interface YYClassIvarInfo : NSObject
     @property (nonatomic, assign, readonly) Ivar ivar;              ///< ivar opaque struct
     @property (nonatomic, strong, readonly) NSString *name;         ///< Ivar's name
     @property (nonatomic, assign, readonly) ptrdiff_t         ///< Ivar's offset
     @property (nonatomic, strong, readonly) NSString *typeEncoding; ///< Ivar's type encoding
     @property (nonatomic, assign, readonly) YYEncodingType type;    ///< Ivar's type
     
     */
    unsigned int ivarCount = 0; //相当于一个计数器
    Ivar *ivars = class_copyIvarList(cls, &ivarCount);
    if (ivars) {
        NSMutableDictionary *ivarInfos = [NSMutableDictionary new];
        _ivarInfos = ivarInfos;
        for (unsigned int i = 0; i < ivarCount; i++) {
            //得到所有的变量
            YYClassIvarInfo *info = [[YYClassIvarInfo alloc] initWithIvar:ivars[i]];
            if (info.name) ivarInfos[info.name] = info;
        }
        free(ivars);
    }
    
    if (!_ivarInfos) _ivarInfos = @{};
    if (!_methodInfos) _methodInfos = @{};
    if (!_propertyInfos) _propertyInfos = @{};
    
    _needUpdate = NO;
}

- (void)setNeedUpdate {
    _needUpdate = YES;
}

- (BOOL)needUpdate {
    return _needUpdate;
}

+ (instancetype)classInfoWithClass:(Class)cls {
    NSLog(@"classInfoWithClass:(Class)cls");
    if (!cls) return nil;
    
    static CFMutableDictionaryRef classCache;
    static CFMutableDictionaryRef metaCache;
    
    static dispatch_once_t onceToken;
    static dispatch_semaphore_t lock;
    dispatch_once(&onceToken, ^{
        //创建字典
        classCache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        metaCache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        lock = dispatch_semaphore_create(1);
    });
    
    dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
    //得到所有的Value
    BOOL is = class_isMetaClass(cls);
    YYClassInfo *info = CFDictionaryGetValue((cls) ? metaCache : classCache, (__bridge const void *)(cls));
    
    if (info && info->_needUpdate) {
        
        //****************重点*****************************
        [info _update];
    }
    
    dispatch_semaphore_signal(lock);
    if (!info) {
        info = [[YYClassInfo alloc] initWithClass:cls];
        if (info) {
            dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
            //设置所有的key
            CFDictionarySetValue(info.isMeta ? metaCache : classCache, (__bridge const void *)(cls), (__bridge const void *)(info));
            dispatch_semaphore_signal(lock);
        }
    }
    return info;
}

+ (instancetype)classInfoWithClassName:(NSString *)className {
     NSLog(@"classInfoWithClassName:(NSString *)className");
    //通过类的名字得到类
    Class cls = NSClassFromString(className);
    return [self classInfoWithClass:cls];
}

@end
