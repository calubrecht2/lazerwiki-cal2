grammar Dokuwiki;

@header {
package us.calubrecht.lazerwiki.service.parser.doku;
}

@members {
private boolean allowBroken = false;

public void setAllowBroken() { allowBroken = true;}
}


//lexer grammar DokuLexer;

NEWLINE
    : [\r\n]
    ;


HEADER1: '======' ;
HEADER2: '=====' ;
HEADER3: '====' ;
HEADER4: '===' ;
HEADER5: '==' ;

WS: [ \t] ;

LINK_START: '[[' ;
LINK_END: ']]' ;
PIPE: '|';

STAR: '*' ;
DASH: '-' ;

NUM : [0-9]+ ;

WORD
    : [A-Z0-9a-z]+
    ;



BOLD_TOKEN: '**' ;
ITALIC_TOKEN: '//' ;
UNDERLINE_TOKEN: '__';
MONOSPACE_TOKEN: '\'\'';
SUP_START_TOKEN: '<sup>';
SUP_END_TOKEN: '</sup>';
SUB_START_TOKEN: '<sub>';
SUB_END_TOKEN: '</sub>';
DEL_START_TOKEN: '<del>';
DEL_END_TOKEN: '</del>';
FORCE_LINEBREAK: ' \\\\';
BLOCKQUOTE_START: '>';
UNFORMAT_TOKEN: '%%' ;
UNFORMAT_TAG_START: '<nowiki>';
UNFORMAT_TAG_END: '</nowiki>';

HIDDEN_START: '<hidden>';
HIDDEN_END: '</hidden>';

CHARACTER
   : ~[\r\n]
   ;

IMG_START_TOKEN: '{{';
IMG_END_TOKEN: '}}';

MACRO_START_TOKEN: '~~MACRO~~' ;
MACRO_END_TOKEN: '~~/MACRO~~' ;

NO_TOC_TOKEN: '~~NOTOC~~' ;
YES_TOC_TOKEN: '~~YESTOC~~' ;

//parser grammar DokuParser;

//options { tokenVocab=DokuLexer; }

page
    : ( header | row | just_newline | code_box | blockquote | hidden | control_row | horizontal_rule )* EOF
    ;

code_box:
  ( WS WS+ line ? NEWLINE )
  ;

just_newline
  : (WS? | WS WS WS+) NEWLINE
  ;

header_tok
   : HEADER1 | HEADER2 | HEADER3 | HEADER4 | HEADER5
   ;

link_target
  : (WORD | NUM | CHARACTER | WS | ITALIC_TOKEN | DASH | UNDERLINE_TOKEN) *
  ;

link_display
  :
  PIPE (all_char | image)*
  ;

link:
 LINK_START link_target link_display? LINK_END
 ;


bold_span
  :
    BOLD_TOKEN (all_char | link | PIPE | NEWLINE | no_bold_span)+? BOLD_TOKEN
  ;

italic_span
  :
    ITALIC_TOKEN (all_char | link | PIPE | NEWLINE | no_italic_span)+? ITALIC_TOKEN
  ;

underline_span
  :
      UNDERLINE_TOKEN (all_char | link | PIPE | NEWLINE | no_underline_span)+? UNDERLINE_TOKEN
  ;

monospace_span
  :
      MONOSPACE_TOKEN (all_char | link | PIPE | NEWLINE | styled_span)+? MONOSPACE_TOKEN
  ;

sup_span
  :
      SUP_START_TOKEN (all_char | link | PIPE | NEWLINE | styled_span)+? SUP_END_TOKEN
  ;

sub_span
  :
      SUB_START_TOKEN (all_char | link | PIPE | NEWLINE | styled_span)+? SUB_END_TOKEN
  ;

del_span
  :
      DEL_START_TOKEN (all_char | link | PIPE | NEWLINE | styled_span)+? DEL_END_TOKEN
  ;

unformat_span
  :
     (UNFORMAT_TOKEN (all_char | link | PIPE | NEWLINE | no_unformat_span | broken_span)+? UNFORMAT_TOKEN) |
     (UNFORMAT_TAG_START ((all_char | link | PIPE | NEWLINE | no_unformat_span | broken_span)+? UNFORMAT_TAG_END))
  ;

all_char
   : all_char_nows |DASH | STAR | WS | BLOCKQUOTE_START | NO_TOC_TOKEN | YES_TOC_TOKEN
   ;

all_char_nows
   :
     WORD | NUM | CHARACTER |  broken_header
  ;

broken_header
  :
  { allowBroken}? header_tok
  ;

broken_bold_span
   :
     BOLD_TOKEN (all_char | link | PIPE )*
   ;

broken_italic_span
   :
     ITALIC_TOKEN (all_char | link | PIPE )*
   ;

broken_underline_span
   :
     UNDERLINE_TOKEN (all_char | link | PIPE )*
   ;

broken_monospace_span
   :
     MONOSPACE_TOKEN (all_char | link | PIPE )*
   ;

broken_sup
  :
   SUP_START_TOKEN | SUP_END_TOKEN
  ;

broken_sub
  :
   SUB_START_TOKEN | SUB_END_TOKEN
  ;

broken_del
  :
   DEL_START_TOKEN | DEL_END_TOKEN
  ;

broken_unformat
  :
    UNFORMAT_TOKEN | UNFORMAT_TAG_END | UNFORMAT_TAG_END
  ;

styled_span
  :
    (bold_span | italic_span | underline_span | monospace_span| sup_span| sub_span| del_span | unformat_span )
  ;

// Can create "no_x_span" for other styled_spans, but not that worried about them, less used.
no_bold_span
:
( italic_span | underline_span | monospace_span| sup_span| sub_span| del_span | unformat_span )
;

no_italic_span
  :
    (bold_span  | underline_span | monospace_span| sup_span| sub_span| del_span | unformat_span)
  ;

no_underline_span
   :
      (bold_span | italic_span  | monospace_span| sup_span| sub_span| del_span | unformat_span)
   ;

no_unformat_span
  :
        (bold_span | italic_span  | monospace_span| sup_span| sub_span| del_span | underline_span)
  ;

broken_span
 :
 { allowBroken}? broken_bold_span | broken_italic_span | broken_underline_span | broken_monospace_span | broken_sup | broken_sub | broken_del | broken_unformat
 ;

olist_item
  :
    WS+ DASH (IMG_START_TOKEN NUM IMG_END_TOKEN)?  (inner_text | styled_span | macro )+
  ;

ulist_item
  :
    WS+ STAR  (inner_text | styled_span | macro )+
  ;

row:
  ( line  ) NEWLINE
  ;

control_row:
  ( NO_TOC_TOKEN | YES_TOC_TOKEN |  WS+  )+ NEWLINE
  ;

blockquote:
  ( BLOCKQUOTE_START+ WS? (line | WS+)?) NEWLINE
  ;

hidden:
  HIDDEN_START ( header | row | line | just_newline | code_box | blockquote  )* HIDDEN_END
  ;

horizontal_rule:
  DASH DASH DASH DASH+
  ;

image
  : IMG_START_TOKEN inner_text+ (PIPE inner_text)? IMG_END_TOKEN
  ;

broken_image
  :
   { allowBroken}? IMG_START_TOKEN | IMG_END_TOKEN
  ;

macro
  :
    MACRO_START_TOKEN (line_item | NEWLINE)+  MACRO_END_TOKEN
  ;

broken_macro
 :
   { allowBroken}? MACRO_START_TOKEN | MACRO_END_TOKEN
 ;

broken_link
  :
   { allowBroken}? LINK_START | LINK_END
  ;


inner_text
  :
    (all_char | link | broken_link | PIPE )
  ;

inner_text_ext
  :
    (all_char | link | broken_link | PIPE | line_break )+
  ;

inner_text_nowsstart
  :
    WS? (all_char_nows | link | broken_link |  PIPE )
  ;

header
  : WS? header_tok inner_text_ext header_tok WS* NEWLINE
  ;

line_break
  : FORCE_LINEBREAK
  ;



line_item
 :
   (inner_text | styled_span | broken_span | image | broken_image | line_break )
;

line
  : (ulist_item | olist_item ) | ((image | (WS? styled_span) | (WS? broken_span) | inner_text_nowsstart | broken_image | macro | broken_macro | line_break ) (line_item |  macro | broken_macro)*)
  ;


