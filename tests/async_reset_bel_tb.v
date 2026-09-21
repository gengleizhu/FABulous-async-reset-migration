`timescale 1ns/1ps

module async_reset_bel_tb;
    reg [3:0] I = 4'b0000;
    reg Ci = 1'b0;
    reg SR = 1'b0;
    reg EN = 1'b0;
    reg UserCLK = 1'b0;
    reg [19:0] ConfigBits = 20'b0;
    wire O;
    wire Co;

    LUT4c_frame_config_dffesr dut (
        .I(I),
        .O(O),
        .Ci(Ci),
        .Co(Co),
        .SR(SR),
        .EN(EN),
        .UserCLK(UserCLK),
        .ConfigBits(ConfigBits)
    );

    always #5 UserCLK = ~UserCLK;

    task wait_clock;
        begin
            @(posedge UserCLK);
            #1;
        end
    endtask

    task expect_o;
        input expected;
        input [8*64-1:0] label;
        begin
            if (O !== expected) begin
                $display("FAIL: %0s expected=%b actual=%b time=%0t", label, expected, O, $time);
                $fatal(1);
            end
            $display("PASS: %0s value=%b time=%0t", label, O, $time);
        end
    endtask

    initial begin
        // LUT output follows I[0]; select registered output.
        ConfigBits[15:0] = 16'hAAAA;
        ConfigBits[16] = 1'b1;
        ConfigBits[17] = 1'b0;

        // Synchronous clear: EN has priority, so reset is ignored while EN=0.
        ConfigBits[19] = 1'b0;
        ConfigBits[18] = 1'b0;
        I[0] = 1'b1;
        EN = 1'b1;
        SR = 1'b0;
        wait_clock;
        expect_o(1'b1, "sync setup to one");

        EN = 1'b0;
        SR = 1'b1;
        wait_clock;
        expect_o(1'b1, "sync clear blocked by EN=0");

        EN = 1'b1;
        wait_clock;
        expect_o(1'b0, "sync clear active when EN=1");
        SR = 1'b0;

        // Asynchronous clear overrides EN and does not wait for a clock edge.
        ConfigBits[19] = 1'b1;
        ConfigBits[18] = 1'b0;
        I[0] = 1'b1;
        EN = 1'b1;
        wait_clock;
        expect_o(1'b1, "async clear setup to one");

        EN = 1'b0;
        #2 SR = 1'b1;
        #1 expect_o(1'b0, "async clear overrides EN=0");
        SR = 1'b0;

        // Asynchronous set also overrides EN and loads configured value one.
        ConfigBits[18] = 1'b1;
        I[0] = 1'b0;
        EN = 1'b1;
        wait_clock;
        expect_o(1'b0, "async set setup to zero");

        EN = 1'b0;
        #2 SR = 1'b1;
        #1 expect_o(1'b1, "async set overrides EN=0");
        SR = 1'b0;

        $display("ASYNC_RESET_BEL_TEST_PASS");
        $finish;
    end
endmodule
