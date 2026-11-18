#import <Foundation/Foundation.h>

#ifndef FILELOGGING
#define FILELOGGING

void _FLog(const char *functionName, int lineNumber, NSString *msgFormat, ...) {
    va_list ap;
    va_start(ap, msgFormat);
    NSString *logFormattedMessage = [[NSString alloc] initWithFormat:msgFormat arguments:ap];
    va_end(ap);
    NSLog(@"[Asteroid] %s[%d] %@", functionName, lineNumber, logFormattedMessage);
}

#endif // FILELOGGING
