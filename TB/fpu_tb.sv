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

    always #5 clock = ~clock;  //Clock de 100kHz 

    // Função auxiliar para montar o valor binário com padrão customizado
    function [31:0] monta_fp;
        input bit       sinal;
        input [6:0]     exp;
        input [23:0]    mant;
        begin
            monta_fp = {sinal, exp, mant};
        end
    endfunction

    initial begin
        clock = 0;
        start = 0;
    #10 reset = 1;

    // === Teste 1: Dois positivos pequenos (2.0 + 1.5) ===
        #10 op_A_in = 32'h40000000;  // 2.0
            op_B_in = 32'h3FC00000;  // 1.5
        $display("=== Teste 1: Dois positivos pequenos (2.0 + 1.5) ===");
        #10 start = 1; #10 start = 0;
        #200;
        $display("data_out   = %h", data_out);
        $display("status_out = %b\n", status_out);

        // === Teste 2: Positivo + Negativo (2.0 + (-1.5)) ===
        #10 op_A_in = 32'h40000000;  // 2.0
            op_B_in = 32'hBFC00000;  // -1.5 (sinal 1)
        $display("=== Teste 2: Positivo + Negativo (2.0 + (-1.5)) ===");
        #10 start = 1; #10 start = 0;
        #200;
        $display("data_out   = %h", data_out);
        $display("status_out = %b\n", status_out);

        // === Teste 3: Subtração com cancelamento (1.0 - 1.0) ===
        #10 op_A_in = 32'h3F800000;  // 1.0
            op_B_in = 32'hBF800000;  // -1.0
        $display("=== Teste 3: Subtração com cancelamento (1.0 - 1.0) ===");
        #10 start = 1; #10 start = 0;
        #200;
        $display("data_out   = %h", data_out);
        $display("status_out = %b\n", status_out);

        // === Teste 4: Arredondamento (1.1 + 1.1) ===
        // 1.1 decimal ~ 0x3F8CCCCD em float IEEE 754 (aprox)
        #10 op_A_in = 32'h3F8CCCCD;  // ~1.1
            op_B_in = 32'h3F8CCCCD;  // ~1.1
        $display("=== Teste 4: Arredondamento (1.1 + 1.1) ===");
        #10 start = 1; #10 start = 0;
        #200;
        $display("data_out   = %h", data_out);
        $display("status_out = %b\n", status_out);

        $stop;
   end

endmodule