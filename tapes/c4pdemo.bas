          
          
1 REM CHALLENGER C4P DEMO V1.0. USES COLOUR AND SOUND          
          
2 REM TERRY STEWART, NEW ZEALAND, 20TH JULY, 2014          
          
3 REM FOR RETROCHALLENGE 2014 (SUMMER)          
          
4 REM FEEL FREE TO LAUGH AT INEFFICIENT NEWBIE CODING          
          
5 LET DELAY=500          
          
6 LET L1 = 39 : REM NUMBER OF LINES IN PART ONE          
          
7 LET L2 = 1 : REM NUMBER OF LINES IN PART TWO          
          
8 LET L3 = 4 :REM NUMBER OF LINES IN PART THREE          
          
9 LET L4 = 5 : REM NUMBER OF LINES IN PART FOUR          
          
10 LET L5 = 25 : REM NUMBER OF LINES IN PART FIVE          
          
11 LET CH = 0 : REM START OF CHARACTER SET          
          
12 LET SD = 57089 : REM FOR SOUND POKE          
               
14 REM CLEAR THE SCREEN AND PRINT INTRODUCTORY MESSSAGE          
          
15 POKE 56832,3 : REM SOUND ON AND B/W SCREEN          
          
20 GOSUB 1500:REM CLEAR SCREEN          
          
28 REM READ IN THE DATA IN THE DATA STATEMENTS          
          
29 REM AND DISPLAY IT LINE BY LINE.          
          
30 FOR DAT = 1 TO L1          
          
40 GOSUB 2000          
          
60 NEXT DAT : REM NEXT LINE          
          
62 POKE SD,0 : REM SOUND OFF          
          
65 FOR I = 1 TO 16:PRINT:NEXT I : REM MAKE ROOM          
          
69 REM DISPLAY CHARACTER SET          
          
70 FOR I = 54144 TO 54654 STEP 2          
          
80 POKE I,CH          
          
85 CH=CH+1          
          
100 NEXT I          
          
103 FOR I = 1 TO DELAY:NEXT I          
          
105 FOR DAT = 1 TO L2          
          
110 GOSUB 2000          
          
120 NEXT DAT : REM NEXT LINE          
          
125 POKE SD,0          
          
130 GOSUB 3050:REM CHECK KEYPRESS          
          
140 IF KY = 3 THEN GOTO 300          
          
150 GOTO 130          
          
299 REM LOOK AT GRAPHICS AND SOUND          
          
300 FOR I = 1 TO 32:PRINT:NEXT I          
          
 302 POKE 56832,7 : REM COLOUR AND SOUND ENABLED          
          
 303 REM COLOUR THE SCREEN          
           
 304 FOR I = 57344 TO 59391:POKE I,12:NEXT I          
           
 305 REM SET UP DIMENSIONS OF WUMPUS CAGE           
          
 306 TL=53322          
                    
 308 TR=53365          
                    
 310 LL=54922          
                    
 312 LR=54965          
          
 314 SC=8:REM SCREEN COLOUR          
          
 316 CC=2:REM CAGE COLOUR          
          
 317 D$="Drawing a Wumpus cage..."          
          
 318 D=55103: GOSUB 3000          
          
 320 POKE TL,204:POKE TL+4096,CC          
          
 322 FOR I = TL+64 TO LL-64 STEP 64          
          
 324 POKE I,140:POKE I+4096,CC          
          
 326 NEXT I          
          
 328 POKE LL,203: POKE LL+4096,CC          
          
 330 FOR I = TL+1 TO TR-1          
          
 332 POKE I,131: POKE I+4096,CC          
          
 334 NEXT I          
          
 336 POKE TR,205:POKE I+4096,CC          
          
 338 FOR I = TR+64 TO LR-64 STEP 64          
          
 340 POKE I,139:POKE I+4096,CC          
          
 342 NEXT I          
          
344 POKE LR,206: POKE LR+4096,CC          
          
346 FOR I = LL+1 TO LR-1           
          
348 POKE I,132:POKE I+4096,CC          
          
350 NEXT I          
          
360 D$="Hang on while the wumpus hides...                             "          
          
361 D=55103: GOSUB 3000          
          
363 START=54240: REM TANK LOCATION IN MIDDLE OF SCREEN          
          
379 REM CALCULATE A RANDOM PLACE FOR THE WUMPUS TO HIDE          
                    
380 WP=INT((LR-TL)*RND(1)+TL)          
          
398 REM MAKE SURE THE WUMPUS IS WITHIN THE BOX          
          
399 REM cHECK EVERY CO-ORD OTHERWISE TRY AGAIN          
          
400 IF WP=TL OR WP=TR OR WP=LL OR WP=LR THEN GOTO 380          
          
420 FOR I = TL+2 TO TR-2          
           
440 FOR J = 1 TO ((LL-TL)-64) STEP 64          
          
460 IF WP=I+J GOTO 500: REM FOUND SO EXIT LOOP          
          
480 NEXT J:NEXT I:GOTO 380: REM TRY AGAIN          
          
500 D$="Sniffing out the wumpus. Here wumpus, wumpus, wumpus..."          
          
510 D=55103: GOSUB 3000          
          
599 REM SET THE TANK ON THE SCREEN          
          
600 POKE START,250          
          
619 REM SMALL DELAY SO TANK CAN BE SEEN          
          
620 FOR T = 1 TO 200:NEXT T          
          
638 REM START OF TANK MOVEMENT          
          
639 REM CALCULATE RANDOM DIRECTION TO MOVE          
                     
640 VL=INT((8-1)*RND(1)+1)          
          
643 REM POSITION OFFSET AND TANK SHAPE          
                    
644 IF VL=1 THEN L=1:TK=250          
                    
648 IF VL=2 THEN L=65:TK=251          
                    
652 IF VL=3 THEN L=64:TK=252              
           
656 IF VL=4 THEN L=63:TK=253                 
           
660 IF VL=5 THEN L=-1:TK=254                  
           
664 IF VL=6 THEN L=-63:TK=249          
                    
668 IF VL=7 THEN L=-64:TK=248          
                    
672 IF VL=8 THEN L=-65:TK=255          
                    
699 REM CALCULATE THE NEW POSITION          
                    
700 PS=START+L          
          
719 REM FORCE THE TANK TO MOVE TOWARDS THE WUMPUS          
                    
720 OC=ABS(WP-START):NC=ABS(WP-PS)          
          
750 IF NC > OC THEN GOTO 640 : REM TRY ANOTHER DIRECTION          
          
779 REM CHECK IF THE NEW POSITION IS THE SAME AS THE WUMPUS          
          
780 IF PS=WP THEN POKE WP,14:GOTO 900:REM FOUND WUMPUS          
               
799 REM IF NOT CARRY ON AND PLACE THE TANK AT NEW POSITION           
          
800 POKE PS,TK          
                    
819 REM PUT A SPACE WHERE THE SHIP WAS          
           
820 POKE START,32          
                    
840 START=PS : REM NEW POSITION BECOMES START          
                    
860 GOTO 640 : REM BACK TO GET A NEW POSITION          
          
899 REM WUMPUS FOUND! PRINT MESSAGE OVERWRITING EXISTING TEXT          
             
900 D$="The wumpus is busted! <L-Shift>=Again, <R-Shift>=Continue "          
          
910 D=55103: GOSUB 3000          
          
1000 GOSUB 3050:REM CHECK KEYPRESS          
          
1004 IF KY=5 THEN POKE START,32:POKE WP,32: GOTO 360          
          
1008 IF KY = 3 THEN GOTO 1020          
          
1010 GOTO 1000          
          
1020 GOSUB 1500 : REM CLEAR SCREEN          
          
1034 REM GREEN SCREEN          
          
1035 FOR I = 53248 TO 55295:POKE I,32:POKE I+4096,5:NEXT I          
          
1037 POKE 56832,6 : REM COLOUR SCREEN          
          
1040 FOR DAT = 1 TO L3          
          
1050 GOSUB 2000          
          
1060 NEXT DAT : REM NEXT LINE          
          
1070 POKE 55040,197          
          
1080 FOR I = 55041 TO 55042          
          
1090 POKE I,226          
          
1100 NEXT I          
          
1110 POKE 55043,195	          
          
1112 FOR DAT = 1 TO L4          
          
1114 GOSUB 2000          
          
1116 NEXT DAT : REM NEXT LINE          
          
1120 GOSUB 3050 :REM CHECK KEYPRESS          
          
1130 IF KY = 3 THEN GOTO 1200          
          
1140 GOTO 1120          
          
1199 REM PART Five          
          
1200 POKE 56832,3 : REM SOUND ON AND B/W          
          
1210 GOSUB 1500 : REM CLEAR SCREEN          
          
1230 REM READ DATA FOR PART 5          
          
1240 FOR DAT = 1 TO L5          
          
1250 GOSUB 2000          
          
1260 NEXT DAT : REM NEXT LINE          
          
1299 REM FINAL SEQUENCE          
          
1300 ST=55121          
          
1310 D$="OSI CHALLENGER ALWAYS!!"          
          
1320 FOR I = 55104 TO 55166          
          
1330 POKE I,11:POKE I+1,12          
          
1340 POKE I-1,32:          
          
1350 IF I-1<ST THEN GOTO 1410          
          
1360 IF I>ST+LEN(D$)+1 THEN GOTO 1410          
          
1370 FOR K= 1 TO LEN(D$)          
          
1380 L= ASC(MID$(D$,K,1))          
          
1390 POKE I+K,9:POKE I+K+1,10          
          
1395 POKE I+K-1,L          
          
1400 NEXT K          
          
1405 I=ST+LEN(D$)+1          
          
1410 FOR J = 1 TO 40:NEXT J          
          
1415 NEXT I          
          
1420 FOR I = 55166 TO 55105 STEP -1          
          
1425 POKE I,10:POKE I-1,9          
          
1430 POKE I+1,32          
          
1435 FOR J = 1 TO 40:NEXT J          
          
1440 NEXT I          
          
1445 GOTO 1320          
          
1499 REM SUBROUTINES          
          
1499 REM CLEAR SCREEN          
          
1500 FOR I = 1 TO 32:PRINT:NEXT I:RETURN          
          
1999 REM SCROLLING WORDS ACROSS THE SCREEN          
          
2000 READ WRD$          
          
2010 LL=LEN(WRD$)          
          
2020 FOR I = 1 TO LL          
          
2030 IF MID$(WRD$,I,1)  ="#" THEN GOSUB2100:PRINT:PRINT:RETURN          
          
2040 PRINT MID$(WRD$,I,1);          
          
2045 POKE SD,160          
          
2050 FOR J=1 TO 15:NEXT J          
          
2055 POKE SD,20          
          
2057 FOR J=1 TO 5:NEXT J          
          
2060 NEXT I          
          
2070 PRINT          
          
2080 RETURN          
          
2099 REM DELAY SUBROUTINE          
          
2100 POKE SD,0          
          
2105 FOR J=1 TO (DELAY/2):NEXT J:          
          
2110 RETURN          
          
2999 REM PRINT AT SUBROUTINE          
          
3000 FOR Y=1 TO LEN(D$)-1:POKE D+Y,ASC(MID$(D$,Y,1)):NEXT:RETURN          
          
3049 REM CHECK KEYPRESS          
          
3050 KY=PEEK(57100):RETURN          
          
5000 DATA "Hiya Kids!#"          
          
5005 DATA "Welcome to the world of 1978-81 and the Ohio Scientific."          
          
5010 DATA "Inc. Challenger 4P.  Here's what ya got for yer cash!#"          
          
5030 DATA "First the basics.  The innards are made up of a series of"          
          
5040 DATA "interconnecting circuit boards housed in a handsome"          
          
5050 DATA "metal case with stylish polished wood sides.#"          
          
5060 DATA "(Not a tacky cheap plastic case like other models!)#"          
          
5070 DATA "As to the engine, how about the awesome 6502 CPU,"          
          
5080 DATA "enhanced by 8K BASIC and supercharged with a whopping 32K"          
          
5090 DATA "of RAM.#"           
          
5095 DATA "Storage is on cassette tape, but a little extra dosh"          
          
5100 DATA "would get you that disk drive.#"          
          
5110 DATA "Now, let me tell you about my 8k Microsoft BASIC.#"           
          
5115 DATA "(Hey don't roll yer eyes, it was good enough for those          
          
5117 DATA "fancy-pants Commodore machines later!)#"          
          
5120 DATA "The BASIC provides all the power ya need! For example...#"          
          
5130 DATA "Commands like : CONT LIST NEW NULL LOAD SAVE and RUN!#"          
          
5140 DATA "Statements like : CLEAR, DATA, DEF, DIM, END, FOR, GOTO,"          
          
5150 DATA "GOSUB, IF...GOTO, IF...THEN, INPUT, LET, NEXT, ON...GOTO"          
          
5160 DATA "ON...GOSUB, POKE, PRINT, READ, REM, RESTORE, RETURN, STOP!#"          
          
5170 DATA "Then there are all the operators, like "          
          
5180 DATA "-,+,*,/,^,NOT,AND,OR,<,>, >=,<=,=#"          
          
5190 DATA "...and the one or two letter variables from A to Z#.           
          
5200 DATA "You can also use these in an array and what is more,"          
          
5210 DATA "those letters can be string variables with the $ sign.#"          
          
5220 DATA "Hey, you want functions?  I got 'em.  ABS(X), ATN(X),"          
          
5230 DATA "COS(X), EXP(X), FRE(X), INT(X), LOG(X), PEEK(I), POS(I), "          
          
5240 DATA "RND(X), SGN(X), SIN(X), SPC(I), SQR(X), TAB(I), TAN(X) and"          
          
5250 DATA "even USR(I) for calling those machine language routines.#"          
          
5255 DATA "(What?  You don't know what machine language is?  Get"          
          
5257 DATA "outta here?)!#"          
          
5260 DATA "For manipulating those strings how about ASC(X),"          
          
5270 DATA "CHR$(X), FRE(X$), LEFT$(X$,I), LEN(X$), MID$(X$,I,J),"          
          
5280 DATA "RIGHT(X$,I), STR(X) AND VAL(X$).#"          
          
5290 DATA "So, throw away that slide rule, balance that checkbook and"          
          
5300 DATA "organise those recipies!#"          
          
5310 DATA "(Go on, you know you want to!)#"          
          
5320 DATA "Hey, ya want graphic symbols for games or decoration?"          
          
5330 DATA "I've gotta whole leggo-box of characters here!#"            
          
5329 REM DATA FOR SECTION 2          
          
5340 DATA "Now...Press <RIGHT SHIFT> to go wumpus hunting...."            
          
5350 DATA "Did I mention the 32 char mode?#"           
          
5360 DATA "Good for all you old fellas"          
          
5370 DATA "whose eyesight is not what"          
          
5380 DATA "it used to be#!"          
          
5390 DATA "Yea, tell me about it!"          
          
5400 DATA "My RAM chips are feeling the"          
          
5410 DATA "years too!#"          
          
5420 DATA "Now press <RIGHT SHIFT> to "          
          
5430 DATA "close this tour out!#"          
          
5450 DATA "OK, ya wanna be connected? I've got heaps of ports"          
          
5455 DATA "hanging off the back here,#"          
          
5460 DATA "As well as the obvious sound and video we have..."          
          
5470 DATA "--------------> DAC (Digital to Analogue Converter)"          
          
5480 DATA "--------------> AC Control (Switches, monitors)"          
          
5490 DATA "--------------> Cassette I/O"          
          
5500 DATA "--------------> 2 X Keypads (Well, why not!)"          
          
5510 DATA "--------------> 2 X Joysticks"          
          
5520 DATA "--------------> Modem port"          
          
5530 DATA "--------------> Serial Printer port"          
          
5540 DATA "--------------> Port A (Periphieral Interface Adaptor)"          
          
5550 DATA "--------------> Port B (Periphieral Interface Adaptor)"          
          
5560 DATA "--------------> 16 Pin I/O BUS (Yeah!)#"          
          
5570 DATA "'Course with a 505 board instead of a 502 there would"          
          
5580 DATA "disk drives too.#"          
          
5590 DATA "I can wait for that...#"          
          
5600 DATA "So...that's about it.  With me in 1981 you got a REAL"           
          
5610 DATA "MAN's micro not that mamby-pamby 4k toy Commodore was"          
          
5620 DATA "peddling or that glorified Atari video game machine.#"          
          
5630 DATA "TRS-80s and Commodore PETS?  You try hooking them up"          
          
5640 DATA "to something else!#"          
          
5650 DATA "As for that computer named after a fruit...pffff."          
          
5660 DATA "Way ovepriced if ya ask me.#"          
          
5670 DATA "And did any of those above have the Enterprise as a"          
          
5680 DATA " gaming arifact?  You bet your life they didn't!#"          
          
          
                    
