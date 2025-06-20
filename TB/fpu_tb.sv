module fpu_tb;

    logic          clock;
    logic          reset;
    logic  [31:0]  op_A_in;   
    logic  [31:0]  op_B_in;   

    logic [31:0]  data_out;  
    logic [3:0]   status_out;
    logic start;

    fpu dut(
        .clock(clock),
        .reset(reset),
        .start(start),
        .op_A_in(op_A_in),
        .op_B_in(op_B_in),
        .data_out(data_out),
        .status_out(status_out)
    );

    always #5 clock = ~clock;  //Clock 100kHz

    // funçao para montar o numero no formato personaliado
    function [31:0] monta_fp;
        input bit       sinal;
        input [6:0]     exp;
        input [23:0]    mant;
        begin
            monta_fp = {sinal, exp, mant};
        end
    endfunction

    task automatic automatic_input(
        input [31:0] A,
        input [31:0] B,
        input string test_name
    );
        begin
            $display("\n================== %s ==================", test_name);
            #10;
            op_A_in <= A;
            op_B_in <= B;
            #10 start = 1; #10 start = 0;
            #1000;

            $display("A       = %h", A);
            $display("B       = %h", B);
            $display("Saida   = %h", data_out);
            $display("Status  = %b", status_out);
            $display("=========================================\n");
        end
    endtask

   initial begin
    clock = 0;
    start = 0;
    reset = 0;
    #10 reset = 1;

    //0+0
    automatic_input(monta_fp(0, 7'd0, 24'd0), monta_fp(0, 7'd0, 24'd0), "TEST 1: Zero + Zero");

    //Soma normal
    automatic_input(monta_fp(0, 7'd64, 24'h800000), monta_fp(0, 7'd63, 24'hC00000), "TEST 2: 2.0 + 1.5");

    //sSoma com sinais diferentes
    automatic_input(monta_fp(0, 7'd64, 24'h800000), monta_fp(1, 7'd63, 24'hC00000), "TEST 3: 2.0 + (-1.5)");

    //Subtração com meso valor
    automatic_input(monta_fp(0, 7'd63, 24'h400000), monta_fp(1, 7'd63, 24'h400000), "TEST 4: 1.0 - 1.0");

    //Soma de dois iguais
    automatic_input(monta_fp(0, 7'd63, 24'h19999A), monta_fp(0, 7'd63, 24'h19999A), "TEST 5: 1.1 + 1.1");

    //Teste de exp maximo 
    automatic_input(monta_fp(0, 7'd127, 24'h7FFFFF), monta_fp(0, 7'd127, 24'h7FFFFF), "TEST 6: Overflow");

    //Teste p mantissa mt pequena
    automatic_input(monta_fp(0, 7'd1, 24'h000001), monta_fp(0, 7'd1, 24'h000001), "TEST 7: Underflow");

    //Identidade da adição: x + 0 = x
    automatic_input(monta_fp(0, 7'd64, 24'h400000), monta_fp(0, 7'd0, 24'd0), "TEST 8: x + 0 = x");

    //Simetria: -x + x = 0
    automatic_input(monta_fp(1, 7'd65, 24'h400000), monta_fp(0, 7'd65, 24'h400000), "TEST 9: -x + x = 0");

    //Subtração com expoentes diferentes (x - y)
    automatic_input(monta_fp(0, 7'd63, 24'h000001), monta_fp(1, 7'd64, 24'h000001), "TEST 10: Subtracao com expoente diferente");

    #100;
    $stop;
    end

endmodule
