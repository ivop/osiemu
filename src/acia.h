#pragma once

#define CONTROL_DIV_MASK    0x03        // divider 1,16,64,master reset
#define CONTROL_WS_MASK     0x1c        // see below
#define CONTROL_TX_CTRL     0x60        // transmit control
#define CONTROL_RX_IRQE     0x80        // receive interrupt enable

#define STATUS_RDRF_MASK    0x01        // Rx data register full
#define STATUS_TDRE_MASK    0x02        // Tx data register empty
#define STATUS_nDCD_MASK    0x04        // /DCD Data Carrier Detect
#define STATUS_nCTS_MASK    0x08        // /CTS Clear To Send
#define STATUS_FE_MASK      0x10        // Rx Frame Error
#define STATUS_OVRN_MASK    0x20        // Rx Overrun
#define STATUS_PE_MASK      0x40        // Rx Parity Error
#define STATUS_IRQ_MASK     0x80        // /IRQ, if pin output is low, bit is 1
                                        // clear by read of RDR

#define setbit(v,msk)   (v) |= (msk)
#define clrbit(v,msk)   (v) &= ~(msk)
#define getbit(v,msk)   (v & (msk))
#define cpybit(v,msk,b) { if (b) setbit(v,msk); else clrbit(v,msk); }
