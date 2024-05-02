module counter(input isHalt, input clk);

    reg [31:0] count = 0;

    always @(posedge clk) begin
        if (isHalt) begin
            $fdisplay(32'h8000_0002,"%d\n",count);
            $finish;
        end
        if (count == 2000) begin
            $display("ran for 2000 cycles");
            $finish;
        end
        //if (count[8:0] == 0) begin
        //    $display("HI");
        //end
        count <= count + 1;
    end

endmodule
