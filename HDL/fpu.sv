module fpu(
    input logic         clock,      //clock 100KHz
    input logic         reset,
    input logic         op_A_in,    //parcelas da soma 
    input logic         op_B_in,    //       ''

    output logic        data_out,  //resultado
    output logic [2:0]  status_out
);

//reg signal, expoent, mantissa
//       
//s 31:30
//e 29:20
//m 19:0


typedef enum logic [2:0] { //n sei se precisa
    EXACT,
    OVERFLOW,
    UNDERFLOW,
    INEXACT

}state_t;

state_t state;




endmodule