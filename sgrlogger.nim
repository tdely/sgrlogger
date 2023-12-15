import std / [logging]
from logging {.all.} import defaultFlushThreshold, level

type
  SgrAttr* = distinct range[0..255] ## \
    ## ECMA-48 Select Graphic Rendition (SGR) attributes.
    ##
    ## For details see:
    ## * https://man7.org/linux/man-pages/man4/console_codes.4.html
  SgrMap* = object
    ## Mapping of SGR sequences to log levels.
    debug, info, notice, warn, error, fatal: string
  SgrLogger* = ref object of Logger
    ## Console logger with SGR.
    useStderr*: bool       ## If true, writes to stderr; otherwise, writes to stdout.
    flushThreshold*: Level ## Only messages that are at or above this threshold
                           ## will be flushed immediately.
    sgrMap*: SgrMap        ## Map of SGR sequences to be applied to different log levels.

const
  SgrReset* = SgrAttr(0)
  SgrBold* = SgrAttr(1)
  SgrDim* = SgrAttr(2)
  SgrItalic* = SgrAttr(3)
  SgrUnderline* = SgrAttr(4)
  SgrBlink* = SgrAttr(5)
  SgrNegative* = SgrAttr(7)
  SgrStrikethrough* = SgrAttr(9)
  SgrFgBlack* = SgrAttr(30)
  SgrFgRed* = SgrAttr(31)
  SgrFgGreen* = SgrAttr(32)
  SgrFgYellow* = SgrAttr(33)
  SgrFgBlue* = SgrAttr(34)
  SgrFgMagenta* = SgrAttr(35)
  SgrFgCyan* = SgrAttr(36)
  SgrFgWhite* = SgrAttr(37)
  SgrFg* = SgrAttr(38) ## \
  ## 256/24-bit foreground color follows.
  ## Use as either `@[SgrFg, SgrAttr(2), SgrAttr(0), SgrAttr(0), SgrAttr(0)]`
  ## or `@[SgrFg, SgrAttr(5), SgrAttr(0)]`.
  SgrFgDefault* = SgrAttr(39)
  SgrBgBlack* = SgrAttr(40)
  SgrBgRed* = SgrAttr(41)
  SgrBgGreen* = SgrAttr(42)
  SgrBgYellow* = SgrAttr(43)
  SgrBgBlue* = SgrAttr(44)
  SgrBgMagenta* = SgrAttr(45)
  SgrBgCyan* = SgrAttr(46)
  SgrBgWhite* = SgrAttr(47)
  SgrBg* = SgrAttr(48) ## \
  ## 256/24-bit background color follows.
  ## Use as either `@[SgrBg, SgrAttr(2), SgrAttr(r), SgrAttr(g), SgrAttr(b)]`
  ## or `@[SgrBg, SgrAttr(5), SgrAttr(x)]`.
  SgrBgDefault* = SgrAttr(49)
  SgrFgBrightBlack* = SgrAttr(90)
  SgrFgBrightRed* = SgrAttr(91)
  SgrFgBrightGreen* = SgrAttr(92)
  SgrFgBrightYellow* = SgrAttr(93)
  SgrFgBrightBlue* = SgrAttr(94)
  SgrFgBrightMagenta* = SgrAttr(95)
  SgrFgBrightCyan* = SgrAttr(96)
  SgrFgBrightWhite* = SgrAttr(97)
  SgrBgBrightBlack* = SgrAttr(100)
  SgrBgBrightRed* = SgrAttr(101)
  SgrBgBrightGreen* = SgrAttr(102)
  SgrBgBrightYellow* = SgrAttr(103)
  SgrBgBrightBlue* = SgrAttr(104)
  SgrBgBrightMagenta* = SgrAttr(105)
  SgrBgBrightCyan* = SgrAttr(106)
  SgrBgBrightWhite* = SgrAttr(107)

proc `$`*(sgr: SgrAttr): string =
  $sgr.int

proc len*(sgr: SgrAttr): int =
  len($sgr)

const
  defaultColors = "\e[" & $SgrFgDefault & ";" & $SgrBgDefault & "m"
  defaultSgrMap* = SgrMap(
    debug: "\e[" & $SgrDim & "m",
    info: "\e[" & $SgrFgGreen & "m",
    notice: "\e[" & $SgrFgCyan & "m",
    warn: "\e[" & $SgrFgYellow & "m",
    error: "\e[" & $SgrFgRed & "m",
    fatal: "\e[" & $SgrFgBrightRed & "m"
  ) ## \
  ## The default SGR map with distinct foreground colors for each log level:
  ##
  ## * **Debug** - dim/half-bright
  ## * **Info** - green
  ## * **Notice** - cyan
  ## * **Warn** - yellow
  ## * **Error** - red
  ## * **Fatal** - bright red

proc createSgrSequence*(sgr: sink seq[SgrAttr]): string =
  ## Create an SGR sequence.
  if sgr.len > 0:
    var l = 3 + (sgr.len-1)
    for i in 0..sgr.high:
      inc(l, sgr[i].len)
    result = newStringOfCap(l)
    result.add "\e["
    result.add $sgr[0]
    for i in 1..sgr.high:
      result.add ";" & $sgr[i]
    result.add "m"

{.warning[ImplicitDefaultValue]: off.}

proc newSgrMap*(debug, info, notice, warn, error, fatal: sink seq[SgrAttr] = @[]): SgrMap =
  ## Create a custom `SgrMap`.
  result.debug = createSgrSequence(debug)
  result.info = createSgrSequence(info)
  result.notice = createSgrSequence(notice)
  result.warn = createSgrSequence(warn)
  result.error = createSgrSequence(error)
  result.fatal = createSgrSequence(fatal)

{.warning[ImplicitDefaultValue]: on.}

proc get(sm: SgrMap, level: Level): string =
  case level
  of lvlDebug:
    sm.debug
  of lvlInfo:
    sm.info
  of lvlNotice:
    sm.notice
  of lvlWarn:
    sm.warn
  of lvlError:
    sm.error
  of lvlFatal:
    sm.fatal
  else:
    defaultColors

proc format(logger: SgrLogger, ln: string, level: Level): string =
  logger.sgrMap.get(level) & ln & "\e[" & $SgrReset & "m"

method log*(logger: SgrLogger, level: Level, args: varargs[string, `$`]) =
  if level >= logging.level and level >= logger.levelThreshold:
    let ln = logger.format(substituteLog(logger.fmtStr, level, args), level)
    try:
      var handle = stdout
      if logger.useStderr:
        handle = stderr
      writeLine(handle, ln)
      if level >= logger.flushThreshold: flushFile(handle)
    except IOError:
      discard

proc newSgrLogger*(levelThreshold = lvlAll, fmtStr = defaultFmtStr,
    sgrMap = defaultSgrMap, useStderr = false,
    flushThreshold = defaultFlushThreshold): SgrLogger =
  ## Create a new `SgrLogger<#SgrLogger>`_.
  new result
  result.fmtStr = fmtStr
  result.sgrMap = sgrMap
  result.levelThreshold = levelThreshold
  result.flushThreshold = flushThreshold
  result.useStderr = useStderr
