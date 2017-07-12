//
//  ZDImageLocalCache.m
//  ZDImageViewer
//
//  Created by stephenw on 2017/7/12.
//  Copyright © 2017年 stephenw.cc. All rights reserved.
//

#import "ZDImageLocalCache.h"
#include <iostream>
#include <vector>
#include <unordered_map>

using namespace std;

template <class K, class T>
struct ZDCacheNode {
  K key;
  T data;
  ZDCacheNode *prev, *next;
};

template <class K, class T>
class ZDLRUCache {
  
public:
  ZDLRUCache(size_t capability) {
    nodes = new ZDCacheNode<K, T>[capability];
    for (int i = 0; i < capability; ++i) {
      availableNodes.push_back(nodes + i);
    }
    head = new ZDCacheNode<K, T>;
    tail = new ZDCacheNode<K, T>;
    head->prev = NULL;
    head->next = tail;
    tail->prev = head;
    tail->next = NULL;
  }
  ~ZDLRUCache() {
    delete head;
    delete tail;
    delete [] nodes;
  }
  
  K Put(K key, T data){
    ZDCacheNode<K, T> *node = hashMap[key];
    if(node){ // node exists
      detach(node);
      node->data = data;
      attach(node);
      return K();
    }
    else{
      K erasedKey = K();
      if(availableNodes.empty()){// 可用结点为空，即cache已满
        node = tail->prev;
        detach(node);
        hashMap.erase(node->key);
        erasedKey = node->key;
      } else {
        node = availableNodes.back();
        availableNodes.pop_back();
      }
      node->key = key;
      node->data = data;
      hashMap[key] = node;
      attach(node);
      return erasedKey;
    }
  }
  T Get(K key){
    ZDCacheNode<K, T> *node = hashMap[key];
    if(node){
      detach(node);
      attach(node);
      return node->data;
    } else{// 如果cache中没有，返回NULL
      return T();
    }
  }
  
private:
  ZDCacheNode<K, T> *head, *tail;
  unordered_map<K, ZDCacheNode<K, T> *> hashMap;
  vector<ZDCacheNode<K, T> *> availableNodes;  //nodes addresses that are available
  ZDCacheNode<K, T> *nodes;   //nodes in double-linked table
  
  // detach node
  void detach(ZDCacheNode<K, T>* node){
    node->prev->next = node->next;
    node->next->prev = node->prev;
  }
  // insert node to head
  void attach(ZDCacheNode<K, T>* node){
    node->prev = head;
    node->next = head->next;
    head->next = node;
    node->next->prev = node;
  }
};

@interface ZDImageLocalCache () <NSCacheDelegate>

@end

@interface ZDImageCacheObjectWrapper: NSObject

@property (nonatomic, copy) NSString *key;
@property (nonatomic, strong) UIImage *image;

@end

static ZDLRUCache<string, string> *lruCache;
static NSCache *memCache;

@implementation ZDImageLocalCache

+ (instancetype)sharedCache {
  static ZDImageLocalCache *sharedCache;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedCache = [ZDImageLocalCache new];
    lruCache = new ZDLRUCache<string, string>(100);
    memCache = [NSCache new];
    memCache.countLimit = 50;
    memCache.delegate = sharedCache;
  });
  return sharedCache;
}

- (void)setImage:(UIImage *)image forKey:(NSString *)key {
  ZDImageCacheObjectWrapper *wrapper = [ZDImageCacheObjectWrapper new];
  wrapper.key = key.copy;
  wrapper.image = image;
  [memCache setObject:wrapper forKey:key];
}

- (UIImage *)getImageForKey:(NSString *)key {
  ZDImageCacheObjectWrapper *wrapper = [memCache objectForKey:key];
  if (wrapper) {
    return wrapper.image;
  }
  string cachedKey = lruCache->Get(key.UTF8String);
  if (cachedKey.empty()) {
    return nil;
  }
  return [[UIImage alloc] initWithContentsOfFile:[_localCachePath stringByAppendingPathComponent:[NSString stringWithUTF8String:cachedKey.c_str()]]];
}

- (void)setLocalCachePath:(NSString *)localCachePath {
  NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject copy];
  path = [path stringByAppendingPathComponent:localCachePath];
  if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:NULL]) {
    NSError *error;
    BOOL succeed =
    [[NSFileManager defaultManager] createDirectoryAtPath:path
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error];
    NSAssert(succeed == YES, @"create directory error occurred: %@", error.localizedDescription);
  }
  _localCachePath = path.copy;
}

- (void)clearCurrentLocalCache {
  if (self.localCachePath) {
    [[NSFileManager defaultManager] removeItemAtPath:self.localCachePath error:NULL];
  }
}

#pragma mark - NSCacheDelegate
- (void)cache:(NSCache *)cache willEvictObject:(id)obj {
  ZDImageCacheObjectWrapper *imageWrapper = obj;
  string erasedKey = lruCache->Put(imageWrapper.key.UTF8String, imageWrapper.key.UTF8String);
  if (!erasedKey.empty()) {
    [[NSFileManager defaultManager] removeItemAtPath:[_localCachePath stringByAppendingPathComponent:[NSString stringWithUTF8String:erasedKey.c_str()]]
                                                                                               error:NULL];
  }
  BOOL success =
  [UIImageJPEGRepresentation(imageWrapper.image, 1) writeToFile:[_localCachePath stringByAppendingPathComponent:imageWrapper.key]
                                                     atomically:YES];
  NSAssert(success == YES, @"write image cache to disk failed");
}

@end

@implementation ZDImageCacheObjectWrapper

@end
