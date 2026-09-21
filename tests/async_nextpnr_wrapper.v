`default_nettype none
module top_wrapper;
    wire clk, d0, d1, en, sr;
    wire q_esr, q_ess, q_ear, q_eas;

    (* keep *) Global_Clock clk_i (.CLK(clk));
    (* keep *) IO_1_bidirectional_frame_config_pass io_d0 (.O(d0), .I(1'b0), .T(1'b1));
    (* keep *) IO_1_bidirectional_frame_config_pass io_d1 (.O(d1), .I(1'b0), .T(1'b1));
    (* keep *) IO_1_bidirectional_frame_config_pass io_en (.O(en), .I(1'b0), .T(1'b1));
    (* keep *) IO_1_bidirectional_frame_config_pass io_sr (.O(sr), .I(1'b0), .T(1'b1));

    (* keep *) LUTFF_ESR ff_esr (.O(q_esr), .CLK(clk), .E(en), .R(sr), .D(d0));
    (* keep *) LUTFF_ESS ff_ess (.O(q_ess), .CLK(clk), .E(en), .S(sr), .D(d1));
    (* keep *) LUTFF_EAR ff_ear (.O(q_ear), .CLK(clk), .E(en), .R(sr), .D(d0));
    (* keep *) LUTFF_EAS ff_eas (.O(q_eas), .CLK(clk), .E(en), .S(sr), .D(d1));

    (* keep *) IO_1_bidirectional_frame_config_pass io_q_esr (.O(), .I(q_esr), .T(1'b0));
    (* keep *) IO_1_bidirectional_frame_config_pass io_q_ess (.O(), .I(q_ess), .T(1'b0));
    (* keep *) IO_1_bidirectional_frame_config_pass io_q_ear (.O(), .I(q_ear), .T(1'b0));
    (* keep *) IO_1_bidirectional_frame_config_pass io_q_eas (.O(), .I(q_eas), .T(1'b0));
endmodule
`default_nettype wire
