module Parser where

import Data.Char
import Options

data Token = Container String
           | Field String
           | Value String String String
           | Close

parse text opts = header opts ++ generate (scan text) opts ++ footer

-- Scanning --

scan text =
  if null text then []
  else case head text of
    '\'' -> parseName remainder
    '[' -> parseValue remainder
    '}' -> parseClose remainder
    _ -> scan remainder -- Skip
  where remainder = tail text

parseName text =
  [fst result] ++ scan (snd result)
    where result = detect $ scanName text

detect scanned =
  case head text of
    '{' -> (Container input, remainder)
    ' ' -> detect (input, remainder) -- Skip
    ':' -> detect (input, remainder) -- Skip
    _ -> (Field input, text) -- Reuse char in scan
  where input = fst scanned
        text = snd scanned
        remainder = tail text

scanName text =
  if char == '\''
    then ("", tail text)
    else (char : fst result, snd result)
      where char = head text
            result = scanName $ tail text

parseValue text =
  [Value (numbers !! 0) (numbers !! 1) (numbers !! 2)] ++ scan (snd result)
    where result = scanValue text
          numbers = fst result

scanValue text =
  if head text == ']'
    then ([], tail text)
  else parseNumber text

parseNumber text =
  ([fst result] ++ fst next, snd next)
    where result = scanNumber text
          next = scanValue $ snd result

scanNumber text =
  case char of
    ',' -> ("", remainder)
    ']' -> ("", text) -- Reuse char in scanValue
    ' ' -> scanNumber remainder
    _ -> (char : fst result, snd result)
  where char = head text
        remainder = tail text
        result = scanNumber $ remainder

parseClose text = [Close] ++ scan text

-- Generation --

generate tokens opts =
  if null tokens then ""
  else case head tokens of
    Container name -> genClass name remainder opts
    _ -> generate remainder opts -- Skip
  where remainder = tail tokens

genClass name remainder opts =
  if elem name (map munge (optCherries opts))
    then
      mkClass 2 (toPascal name)
      ++ fst fields
      ++ generate (snd fields) opts
    else "" ++ generate remainder opts
      where fields = genFields remainder (optIgnores opts)

genFields tokens ignores =
  case head tokens of
    Field name -> (genField name next ignores ++ fst result, snd result)
    Value def _ _ -> (mkField def ++ fst result, snd result)
    Close -> (mkClose, tail tokens)
  where result = genFields (tail tokens) ignores
        next = head $ tail tokens

genField name next ignores =
  if elem name (map munge ignores) then "" -- Skip ignored names
  else case next of
    Value _ min max -> mkRange min max ++ field
    _ -> tab 3 ++ field
  where field = mkFloat ++ toCamel name

-- Replace underscore with space
munge ignore =
  if null ignore then ""
  else if char == '_' then ' ' : munge remainder
  else char : munge remainder
    where char = head ignore
          remainder = tail ignore

-- No case to Pascal case conversion
toPascal name = toUpper (head name) : toCamel (tail name)

-- No case to camel case conversion
toCamel name =
  if null name
    then ""
  else if char == ' '
    then toUpper (head remainder) : toCamel (tail remainder)
  else char : toCamel remainder
    where char = head name
          remainder = tail name

-- C# string functions --

endl = "\n"
tab count = concat $ replicate count "  "

header opts =
  "/* Generated by acgaudette/pparse; do not modify */"
  ++ foldl (\acc i -> acc ++ endl ++ endl ++ using i) "" (optIncludes opts)
  ++ endl ++ endl
  ++ case optNamespace opts of
    Just name -> "namespace " ++ name ++ " "
    Nothing -> ""
  ++ "{" ++ endl
  ++ mkClass 1 (maybe "Properties" (++"") (optContainer opts))

footer = tab 1 ++ "}" ++ endl ++ "}" ++ endl

using include = "using " ++ include ++ ";"

mkClass indent name = endl
  ++ tab indent ++ "[System.Serializable]" ++ endl
  ++ tab indent ++ "public class " ++ name ++ " {" ++ endl

mkRange min max = tab 3
  ++ "[Range(" ++ min ++ "f, " ++ max ++ "f)] "

mkFloat = "public float "

mkField value = " = " ++ value ++ "f;" ++ endl

mkClose = tab 2 ++ "}" ++ endl
