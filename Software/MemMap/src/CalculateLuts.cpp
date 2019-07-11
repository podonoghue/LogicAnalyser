/*
 * CalculateLuts.cpp
 *
 *  Created on: 7 Jul 2019
 *      Author: podonoghue
 */
#include <stdint.h>
#include <stdio.h>

enum TriggerEncoding {t_X, t_H, t_L, t_R, t_F, t_C,};

static const uint16_t lutEncoding[] = {
   0b1111111111111111,  // XX
   0b1010101010101010,  // XH
   0b0101010101010101,  // XL
   0b0010001000100010,  // XR
   0b0100010001000100,  // XF
   0b0110011001100110,  // XC
   0b1111000011110000,  // HX
   0b1010000010100000,  // HH
   0b0101000001010000,  // HL
   0b0010000000100000,  // HR
   0b0100000001000000,  // HF
   0b0110000001100000,  // HC
   0b0000111100001111,  // LX
   0b0000101000001010,  // LH
   0b0000010100000101,  // LL
   0b0000001000000010,  // LR
   0b0000010000000100,  // LF
   0b0000011000000110,  // LC
   0b0000000011110000,  // RX
   0b0000000010100000,  // RH
   0b0000000001010000,  // RL
   0b0000000000100000,  // RR
   0b0000000001000000,  // RF
   0b0000000001100000,  // RC
   0b0000111100000000,  // FX
   0b0000101000000000,  // FH
   0b0000010100000000,  // FL
   0b0000001000000000,  // FR
   0b0000010000000000,  // FF
   0b0000011000000000,  // FC
   0b0000111111110000,  // CX
   0b0000101010100000,  // CH
   0b0000010101010000,  // CL
   0b0000001000100000,  // CR
   0b0000010001000000,  // CF
   0b0000011001100000,  // CC
};

uint16_t getTriggerLutValue(TriggerEncoding triggerValue1, TriggerEncoding triggerValue0) {
   unsigned index = 6*triggerValue1+triggerValue0;
   return lutEncoding[index];
}
// Number of sample inputs
static constexpr int SAMPLE_WIDTH = 16;

// Maximum number of steps in complex trigger sequence
//static constexpr int  MAX_TRIGGER_STEPS = 4;

// Maximum number of conditions for each trigger step (either 2 or 4)
static constexpr int  MAX_CONDITIONS = 2;

// Number of bits for counter for each trigger step
//static constexpr int  MATCH_COUNTER_BITS = 16;

static constexpr int COMPARATORS_PER_LUT = 2;
static constexpr int BITS_PER_LUT        = 2;

struct Trigger {
   TriggerEncoding triggerValue[MAX_CONDITIONS][SAMPLE_WIDTH];
};

void getTriggerLutValue(
      Trigger   &trigger,
      uint32_t   lutValues[MAX_CONDITIONS*SAMPLE_WIDTH/BITS_PER_LUT/COMPARATORS_PER_LUT]) {
   int lutIndex = 0;
   for(int condition=MAX_CONDITIONS-1; condition>=COMPARATORS_PER_LUT-1; condition-=COMPARATORS_PER_LUT) {
      for(int bitNum=SAMPLE_WIDTH-1; bitNum>=BITS_PER_LUT-1; bitNum-=BITS_PER_LUT) {
         lutValues[lutIndex] = getTriggerLutValue(trigger.triggerValue[condition][bitNum],  trigger.triggerValue[condition][bitNum-1]);
         lutValues[lutIndex] <<= 16;
         lutValues[lutIndex] |= getTriggerLutValue(trigger.triggerValue[condition-1][bitNum],  trigger.triggerValue[condition-1][bitNum-1]);
         lutIndex++;
      }
   }
}

TriggerEncoding encodeTriggerValue(char value) {
   switch (value) {
      case '0' :
      case 'L' :
         return t_L;
      case '1' :
      case 'H' :
         return t_H;
      case 'R' :
         return t_R;
      case 'F' :
         return t_F;
      case 'C' :
         return t_C;
      default:
      case 'X' :
         return t_X;
   }
}
void testEncoding() {
   Trigger  trigger;
   uint32_t lutValues[MAX_CONDITIONS*SAMPLE_WIDTH/BITS_PER_LUT];

   const char *comparators[2] = {
         "XXXXXXXXXXX10RFC",
         "XXXXXXXXXXXCFR01",
   };
   for(int condition=MAX_CONDITIONS-1; condition>=0; condition--) {
      for(int bitNum=SAMPLE_WIDTH-1; bitNum>=0; bitNum--) {
         trigger.triggerValue[condition][bitNum] = encodeTriggerValue(comparators[condition][bitNum]);
      }
   }
   getTriggerLutValue(trigger, lutValues);

}


bool risingEdge(bool last, bool current) {
   return !last && current;
}

bool fallingEdge(bool last, bool current) {
   return last && !current;
}

bool eitherEdge(bool last, bool current) {
   return last != current;
}

bool high(bool last, bool current) {
   return current;
}

bool low(bool last, bool current) {
   return !current;
}

bool any(bool last, bool current) {
   return 1;
}

uint32_t evaluate(bool (*f1)(bool last, bool current), bool (*f0)(bool last, bool current)) {
   bool res[32];
   int index=0;
   for (unsigned i4 = 0; i4<=1; i4++) {
      for (unsigned i3 = 0; i3<=1; i3++) {
         for (unsigned i2 = 0; i2<=1; i2++) {
            for (unsigned i1 = 0; i1<=1; i1++) {
               for (unsigned i0 = 0; i0<=1; i0++) {
                  bool v = not i4 && f1(i3,i2) && f0(i1,i0);
                  res[index++] = v;
//                  printf("%1d", res[index-1]);
               }
            }
         }
      }
   }
//   printf("==\n");
   uint32_t value = 0;
   for(index=31; index>=0; index--) {
      printf("%1d", res[index]);
      value = (value<<1) + res[index];
   }
//   printf("\n");

   return value;
}

struct Test {
   const char *name;
   bool (*function)(bool last, bool current);
};

Test functions[] = {
      { "X", any,         },
      { "H", high,        },
      { "L", low,         },
      { "R", risingEdge,  },
      { "F", fallingEdge, },
      { "C", eitherEdge,  },
};

void testLutEncoding() {

   unsigned index=0;
   for (unsigned f1=0; f1<6; f1++) {
      for (unsigned f2=0; f2<6; f2++) {
         uint32_t value = evaluate(functions[f1].function, functions[f2].function);
         printf("// %s%s", functions[f1].name, functions[f2].name);
         if (value != lutEncoding[index++]) {
            printf(" => Opps");
         }
         printf("\n");
      }
   }
}

int main() {
//   testLutEncoding();
   testEncoding();

   return 0;
}
