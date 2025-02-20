%%%===================================================================
%%% Copyright (c) 2013-2019 EMQ Inc. All rights reserved.
%%%
%%% Licensed under the Apache License, Version 2.0 (the "License");
%%% you may not use this file except in compliance with the License.
%%% You may obtain a copy of the License at
%%%
%%%     http://www.apache.org/licenses/LICENSE-2.0
%%%
%%% Unless required by applicable law or agreed to in writing, software
%%% distributed under the License is distributed on an "AS IS" BASIS,
%%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%% See the License for the specific language governing permissions and
%%% limitations under the License.
%%%===================================================================

-module (emqx_sn_protocol_SUITE).

-include_lib("emqx_sn/include/emqx_sn.hrl").

-include_lib("eunit/include/eunit.hrl").
-include_lib("common_test/include/ct.hrl").

-include_lib("emqx/include/emqx.hrl").
-include_lib("emqx/include/emqx_mqtt.hrl").

-compile(export_all).
-compile(nowarn_export_all).

-define(HOST, {127,0,0,1}).
-define(PORT, 1884).

-define(FLAG_DUP(X),X).
-define(FLAG_QOS(X),X).
-define(FLAG_RETAIN(X),X).
-define(FLAG_SESSION(X),X).

-define(LOG(Format, Args), ct:print("TEST: " ++ Format, Args)).

-define(MAX_PRED_TOPIC_ID, 2).
-define(PREDEF_TOPIC_ID1, 1).
-define(PREDEF_TOPIC_ID2, 2).
-define(PREDEF_TOPIC_NAME1, <<"/predefined/topic/name/hello">>).
-define(PREDEF_TOPIC_NAME2, <<"/predefined/topic/name/nice">>).
-define(ENABLE_QOS3, true).
% FLAG NOT USED
-define(FNU, 0).

all() -> [
    connect_test01,connect_test02,connect_test03,

    subscribe_test, subscribe_test1, subscribe_test2, 
    subscribe_test3, subscribe_test4, subscribe_test5, 
    subscribe_test6, subscribe_test7, subscribe_test8,

    publish_negqos_test1, publish_qos0_test1, publish_qos0_test2,
    publish_qos0_test3, publish_qos0_test4, publish_qos0_test5,
    publish_qos0_test6,

    publish_qos1_test1, publish_qos1_test2, publish_qos1_test3,
    publish_qos1_test4, publish_qos1_test5, publish_qos1_test6,

    publish_qos2_test1, publish_qos2_test2, publish_qos2_test3,

    will_test1, will_test2, will_test3, will_test4, will_test5,
    broadcast_test1,
    asleep_test01_timeout, asleep_test02_to_awake_and_back,
    asleep_test03_to_awake_qos1_dl_msg, 
    asleep_test04_to_awake_qos1_dl_msg,
    asleep_test05_to_awake_qos1_dl_msg,
    asleep_test06_to_awake_qos2_dl_msg,
    asleep_test07_to_connected,
    asleep_test08_to_disconnected,
    asleep_test09_to_awake_again_qos1_dl_msg,
    awake_test01_to_connected, awake_test02_to_disconnected
].

init_per_testcase(_TestCase, Config) ->
    emqx_ct_helpers:start_apps([emqx, emqx_sn], fun set_special_configs/1),
    Config.

end_per_testcase(_TestCase, _Config) ->
    emqx_ct_helpers:stop_apps([emqx_sn, emqx]).

connect_test01(_Config) ->
    {ok, Socket} = gen_udp:open(0, [binary]),
    send_connect_msg(Socket, <<"client_id_test1">>),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),
    %% ct:log("client users: ~p", [get_online_user()]),
    gen_udp:close(Socket).

connect_test02(_Config) ->
    {ok, Socket} = gen_udp:open(0, [binary]),
    send_connect_msg(Socket, <<"client_id_test2">>),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),
    timer:sleep(100),
    send_connect_msg(Socket, <<"client_id_test3">>),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),
    gen_udp:close(Socket).

connect_test03(_Config) ->
    {ok, Socket} = gen_udp:open(0, [binary]),
    send_connect_msg(Socket, <<"client_id_test">>),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),
    timer:sleep(100),
    send_connect_msg(Socket, <<"client_id_other">>),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),
    gen_udp:close(Socket).

subscribe_test(_Config) ->
    Dup = 0,
    QoS = 0,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    MsgId = 1,
    TopicId = ?MAX_PRED_TOPIC_ID + 1,
    ReturnCode = 0,
    {ok, Socket} = gen_udp:open(0, [binary]),
    send_connect_msg(Socket, <<"client_id_test">>),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),
    TopicName1 = <<"abcD">>,
    send_register_msg(Socket, TopicName1, MsgId),
    ?assertEqual(<<7, ?SN_REGACK, TopicId:16, MsgId:16, 0:8>>, receive_response(Socket)),
    send_subscribe_msg_normal_topic(Socket, QoS, TopicName1, MsgId),
    ?assertEqual(<<8, ?SN_SUBACK, Dup:1, QoS:2, Retain:1, Will:1,
                   CleanSession:1, ?SN_NORMAL_TOPIC:2, TopicId:16,
                   MsgId:16, ReturnCode>>, receive_response(Socket)),
    ?assertEqual([TopicName1], emqx_broker:topics()),

    send_unsubscribe_msg_normal_topic(Socket, TopicName1, MsgId),
    ?assertEqual(<<4, ?SN_UNSUBACK, MsgId:16>>, receive_response(Socket)),
    ?assertEqual([], emqx_broker:topics()),

    send_disconnect_msg(Socket, undefined),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),

    gen_udp:close(Socket).

subscribe_test1(_Config) ->
    Dup = 0,
    QoS = 0,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    MsgId = 1,
    TopicId = ?MAX_PRED_TOPIC_ID + 1,
    ReturnCode = 0,
    {ok, Socket} = gen_udp:open(0, [binary]),
    send_connect_msg(Socket, <<"client_id_test">>),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),

    TopicName1 = <<"abcD">>,
    send_register_msg(Socket, TopicName1, MsgId),
    ?assertEqual(<<7, ?SN_REGACK, TopicId:16, MsgId:16, 0:8>>, receive_response(Socket)),
    send_subscribe_msg_normal_topic(Socket, QoS, TopicName1, MsgId),
    ?assertEqual(<<8, ?SN_SUBACK, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1,
                   ?SN_NORMAL_TOPIC:2, TopicId:16, MsgId:16, ReturnCode>>,
                 receive_response(Socket)),

    send_unsubscribe_msg_normal_topic(Socket, TopicName1, MsgId),
    ?assertEqual(<<4, ?SN_UNSUBACK, MsgId:16>>, receive_response(Socket)),

    send_disconnect_msg(Socket, undefined),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),

    gen_udp:close(Socket).

subscribe_test2(_Config) ->
    Dup = 0,
    QoS = 0,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    MsgId = 1,
    TopicId = ?PREDEF_TOPIC_ID1, %this TopicId is the predefined topic id corresponding to ?PREDEF_TOPIC_NAME1
    ReturnCode = 0,
    {ok, Socket} = gen_udp:open(0, [binary]),

    send_connect_msg(Socket, <<"client_id_test">>),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),

    Topic1 = ?PREDEF_TOPIC_NAME1,
    send_register_msg(Socket, Topic1, MsgId),
    ?assertEqual(<<7, ?SN_REGACK, TopicId:16, MsgId:16, 0:8>>, receive_response(Socket)),
    send_subscribe_msg_predefined_topic(Socket, QoS, TopicId, MsgId),
    ?assertEqual(<<8, ?SN_SUBACK, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1,
                   ?SN_NORMAL_TOPIC:2, TopicId:16, MsgId:16, ReturnCode>>,
                 receive_response(Socket)),

    send_unsubscribe_msg_predefined_topic(Socket, TopicId, MsgId),
    ?assertEqual(<<4, ?SN_UNSUBACK, MsgId:16>>, receive_response(Socket)),

    send_disconnect_msg(Socket, undefined),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),

    gen_udp:close(Socket).

subscribe_test3(_Config) ->
    Dup = 0,
    QoS = 2,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    MsgId = 1,
    TopicId = 0,
    ReturnCode = 0,
    {ok, Socket} = gen_udp:open(0, [binary]),

    ClientId = <<"ClientA">>,
    send_connect_msg(Socket, ClientId),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),

    send_subscribe_msg_short_topic(Socket, QoS, <<"te">>, MsgId),
    ?assertEqual(<<8, ?SN_SUBACK, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1,
                   ?SN_NORMAL_TOPIC:2, TopicId:16, MsgId:16, ReturnCode>>,
                 receive_response(Socket)),
 
    send_unsubscribe_msg_short_topic(Socket, <<"te">>, MsgId),
    ?assertEqual(<<4, ?SN_UNSUBACK, MsgId:16>>, receive_response(Socket)),

    send_disconnect_msg(Socket, undefined),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),
    gen_udp:close(Socket).

%%In this case We use predefined topic name to register and subcribe, and expect to receive the corresponding predefined topic id but not a new generated topic id from broker. We design this case to illustrate
%% emqx_sn_gateway's compatibility of dealing with predefined and normal topics. Once we give more restrictions to different topic id type, this case would be deleted or modified.
subscribe_test4(_Config) ->
    Dup = 0,
    QoS = 0,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    MsgId = 1,
    TopicId = ?PREDEF_TOPIC_ID1, %this TopicId is the predefined topic id corresponding to ?PREDEF_TOPIC_NAME1
    ReturnCode = 0,
    {ok, Socket} = gen_udp:open(0, [binary]),
    send_connect_msg(Socket, <<"client_id_test">>),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),
    Topic1 = ?PREDEF_TOPIC_NAME1,
    send_register_msg(Socket, Topic1, MsgId),
    ?assertEqual(<<7, ?SN_REGACK, TopicId:16, MsgId:16, 0:8>>, receive_response(Socket)),
    send_subscribe_msg_normal_topic(Socket, QoS, Topic1, MsgId),
    ?assertEqual(<<8, ?SN_SUBACK, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1, ?SN_NORMAL_TOPIC:2, TopicId:16, MsgId:16, ReturnCode>>,
        receive_response(Socket)),

    send_unsubscribe_msg_normal_topic(Socket, Topic1, MsgId),
    ?assertEqual(<<4, ?SN_UNSUBACK, MsgId:16>>, receive_response(Socket)),

    send_disconnect_msg(Socket, undefined),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),

    gen_udp:close(Socket).

subscribe_test5(_Config) ->
    Dup = 0,
    QoS = 1,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    MsgId = 25,
    TopicId0 = 0,
    TopicId1 = ?MAX_PRED_TOPIC_ID + 1,
    TopicId2 = ?MAX_PRED_TOPIC_ID + 2,
    ReturnCode = 0,
    {ok, Socket} = gen_udp:open(0, [binary]),
    ClientId = <<"testu">>,
    send_connect_msg(Socket, ClientId),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),

    send_register_msg(Socket, <<"abcD">>, MsgId),
    ?assertEqual(<<7, ?SN_REGACK, TopicId1:16, MsgId:16, 0:8>>, receive_response(Socket)),

    send_subscribe_msg_normal_topic(Socket, QoS, <<"abcD">>, MsgId),
    ?assertEqual(<<8, ?SN_SUBACK, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1, ?SN_NORMAL_TOPIC:2, TopicId1:16, MsgId:16, ReturnCode>>,
        receive_response(Socket)),

    send_subscribe_msg_normal_topic(Socket, QoS, <<"/sport/#">>, MsgId),
    ?assertEqual(<<8, ?SN_SUBACK, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1, ?SN_NORMAL_TOPIC:2, TopicId0:16, MsgId:16, ReturnCode>>,
        receive_response(Socket)),

    send_subscribe_msg_normal_topic(Socket, QoS, <<"/a/+/water">>, MsgId),
    ?assertEqual(<<8, ?SN_SUBACK, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1, ?SN_NORMAL_TOPIC:2, TopicId0:16, MsgId:16, ReturnCode>>,
        receive_response(Socket)),

    send_subscribe_msg_normal_topic(Socket, QoS, <<"/Tom/Home">>, MsgId),
    ?assertEqual(<<8, ?SN_SUBACK, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1,
                   ?SN_NORMAL_TOPIC:2, TopicId2:16, MsgId:16, ReturnCode>>,
                 receive_response(Socket)),
    send_unsubscribe_msg_normal_topic(Socket, <<"abcD">>, MsgId),
    ?assertEqual(<<4, ?SN_UNSUBACK, MsgId:16>>, receive_response(Socket)),

    send_disconnect_msg(Socket, undefined),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),
    gen_udp:close(Socket).

subscribe_test6(_Config) ->
    Dup = 0,
    QoS = 0,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    MsgId = 1,
    TopicId0 = 0,
    TopicId1 = ?MAX_PRED_TOPIC_ID + 1,
    TopicId2 = ?MAX_PRED_TOPIC_ID + 2,
    ReturnCode = 0,
    {ok, Socket} = gen_udp:open(0, [binary]),
    send_connect_msg(Socket, <<"test">>),

    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),
    send_register_msg(Socket, <<"abc">>, MsgId),
    ?assertEqual(<<7, ?SN_REGACK, TopicId1:16, MsgId:16, 0:8>>, receive_response(Socket)),

    send_register_msg(Socket, <<"/blue/#">>, MsgId),
    ?assertEqual(<<7, ?SN_REGACK, TopicId0:16, MsgId:16, ?SN_RC_NOT_SUPPORTED:8>>, receive_response(Socket)),

    send_register_msg(Socket, <<"/blue/+/white">>, MsgId),
    ?assertEqual(<<7, ?SN_REGACK, TopicId0:16, MsgId:16, ?SN_RC_NOT_SUPPORTED:8>>, receive_response(Socket)),
    send_register_msg(Socket, <<"/$sys/rain">>, MsgId),
    ?assertEqual(<<7, ?SN_REGACK, TopicId2:16, MsgId:16, 0:8>>, receive_response(Socket)),

    send_subscribe_msg_short_topic(Socket, QoS, <<"Q2">>, MsgId),
    ?assertEqual(<<8, ?SN_SUBACK, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1, ?SN_NORMAL_TOPIC:2, TopicId0:16, MsgId:16, ReturnCode>>,
        receive_response(Socket)),

    send_unsubscribe_msg_normal_topic(Socket, <<"Q2">>, MsgId),
    ?assertEqual(<<4, ?SN_UNSUBACK, MsgId:16>>, receive_response(Socket)),

    send_disconnect_msg(Socket, undefined),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),
    gen_udp:close(Socket).

subscribe_test7(_Config) ->
    Dup = 0,
    QoS = 0,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    MsgId = 1,
    TopicId1 = ?MAX_PRED_TOPIC_ID + 2,
    TopicId2 = ?MAX_PRED_TOPIC_ID + 3,
    {ok, Socket} = gen_udp:open(0, [binary]),
    send_connect_msg(Socket, <<"test">>),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),

    send_subscribe_msg_predefined_topic(Socket, QoS, TopicId1, MsgId),
    ?assertEqual(<<8, ?SN_SUBACK, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1, ?SN_NORMAL_TOPIC:2, TopicId1:16, MsgId:16, ?SN_RC_INVALID_TOPIC_ID>>,
        receive_response(Socket)),

    send_unsubscribe_msg_predefined_topic(Socket, TopicId2, MsgId),
    ?assertEqual(<<4, ?SN_UNSUBACK, MsgId:16>>, receive_response(Socket)),
    send_disconnect_msg(Socket, undefined),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),
    gen_udp:close(Socket).

subscribe_test8(_Config) ->
    Dup = 0,
    QoS = 0,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    MsgId = 1,
    TopicId2 = 2,
    {ok, Socket} = gen_udp:open(0, [binary]),
    send_connect_msg(Socket, <<"test">>),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),

    send_subscribe_msg_reserved_topic(Socket, QoS, TopicId2, MsgId),
    ?assertEqual(<<8, ?SN_SUBACK, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1, ?SN_NORMAL_TOPIC:2, ?SN_INVALID_TOPIC_ID:16, MsgId:16, ?SN_RC_INVALID_TOPIC_ID>>,
        receive_response(Socket)),

    send_disconnect_msg(Socket, undefined),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),
    gen_udp:close(Socket).

publish_negqos_test1(_Config) ->
    Dup = 0,
    QoS = 0,
    NegQoS = 3,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    MsgId = 1,
    TopicId1 = ?MAX_PRED_TOPIC_ID + 1,
    {ok, Socket} = gen_udp:open(0, [binary]),
    send_connect_msg(Socket, <<"test">>),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),

    Topic = <<"abc">>,
    send_subscribe_msg_normal_topic(Socket, QoS, Topic, MsgId),
    ?assertEqual(<<8, ?SN_SUBACK, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1, ?SN_NORMAL_TOPIC:2, TopicId1:16, MsgId:16, ?SN_RC_ACCEPTED>>,
                 receive_response(Socket)),

    MsgId1 = 3,
    Payload1 = <<20, 21, 22, 23>>,
    send_publish_msg_normal_topic(Socket, NegQoS, MsgId1, TopicId1, Payload1),
    timer:sleep(100),
    case ?ENABLE_QOS3 of
        true  ->
            Eexp = <<11, ?SN_PUBLISH, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1, ?SN_NORMAL_TOPIC:2, TopicId1:16, (mid(0)):16, <<20, 21, 22, 23>>/binary>>,
            What = receive_response(Socket),
            ?assertEqual(Eexp, What)
    end,
    send_disconnect_msg(Socket, undefined),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),
    gen_udp:close(Socket).

publish_qos0_test1(_Config) ->
    Dup = 0,
    QoS = 0,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    MsgId = 1,
    TopicId1 = ?MAX_PRED_TOPIC_ID + 1,
    {ok, Socket} = gen_udp:open(0, [binary]),
    send_connect_msg(Socket, <<"test">>),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),

    Topic = <<"abc">>,
    send_subscribe_msg_normal_topic(Socket, QoS, Topic, MsgId),
    ?assertEqual(<<8, ?SN_SUBACK, Dup:1, QoS:2, Retain:1, Will:1, 
                   CleanSession:1, ?SN_NORMAL_TOPIC:2, TopicId1:16, 
                   MsgId:16, ?SN_RC_ACCEPTED>>,
                 receive_response(Socket)),
    MsgId1 = 3,
    Payload1 = <<20, 21, 22, 23>>,
    send_publish_msg_normal_topic(Socket, QoS, MsgId1, TopicId1, Payload1),
    timer:sleep(100),

    Eexp = <<11, ?SN_PUBLISH, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1, ?SN_NORMAL_TOPIC:2, TopicId1:16, (mid(0)):16, <<20, 21, 22, 23>>/binary>>,
    What = receive_response(Socket),
    ?assertEqual(Eexp, What),

    send_disconnect_msg(Socket, undefined),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),
    gen_udp:close(Socket).

publish_qos0_test2(_Config) ->
    Dup = 0,
    QoS = 0,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    MsgId = 1,
    PredefTopicId = ?PREDEF_TOPIC_ID1,
    {ok, Socket} = gen_udp:open(0, [binary]),
    send_connect_msg(Socket, <<"test">>),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),

    send_subscribe_msg_predefined_topic(Socket, QoS, PredefTopicId, MsgId),
    ?assertEqual(<<8, ?SN_SUBACK, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1, ?SN_NORMAL_TOPIC:2, PredefTopicId:16, MsgId:16, ?SN_RC_ACCEPTED>>,
        receive_response(Socket)),

    MsgId1 = 3,
    Payload1 = <<20, 21, 22, 23>>,
    send_publish_msg_predefined_topic(Socket, QoS, MsgId1, PredefTopicId, Payload1),
    timer:sleep(100),

    Eexp = <<11, ?SN_PUBLISH, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1, ?SN_PREDEFINED_TOPIC:2, PredefTopicId:16, (mid(0)):16, <<20, 21, 22, 23>>/binary>>,
    What = receive_response(Socket),
    ?assertEqual(Eexp, What),

    send_disconnect_msg(Socket, undefined),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),
    gen_udp:close(Socket).

publish_qos0_test3(_Config) ->
    Dup = 0,
    QoS = 0,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    MsgId = 1,
    TopicId = ?MAX_PRED_TOPIC_ID + 1,
    {ok, Socket} = gen_udp:open(0, [binary]),
    send_connect_msg(Socket, <<"test">>),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),

    Topic = <<"/a/b/c">>,
    send_subscribe_msg_normal_topic(Socket, QoS, Topic, MsgId),
    ?assertEqual(<<8, ?SN_SUBACK, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1, ?SN_NORMAL_TOPIC:2, TopicId:16, MsgId:16, ?SN_RC_ACCEPTED>>,
        receive_response(Socket)),

    MsgId1 = 3,
    Payload1 = <<20, 21, 22, 23>>,
    send_publish_msg_predefined_topic(Socket, QoS, MsgId1, TopicId, Payload1),
    timer:sleep(100),

    Eexp = <<11, ?SN_PUBLISH, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1, ?SN_NORMAL_TOPIC:2, TopicId:16, (mid(0)):16, <<20, 21, 22, 23>>/binary>>,
    What = receive_response(Socket),
    ?assertEqual(Eexp, What),

    send_disconnect_msg(Socket, undefined),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),
    gen_udp:close(Socket).

publish_qos0_test4(_Config) ->
    Dup = 0,
    QoS = 0,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    MsgId = 1,
    TopicId0 = 0,
    {ok, Socket} = gen_udp:open(0, [binary]),
    send_connect_msg(Socket, <<"test">>),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),

    send_subscribe_msg_normal_topic(Socket, QoS, <<"#">>, MsgId),
    ?assertEqual(<<8, ?SN_SUBACK, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1, ?SN_NORMAL_TOPIC:2, TopicId0:16, MsgId:16, ?SN_RC_ACCEPTED>>,
        receive_response(Socket)),

    MsgId1 = 2,
    Payload1 = <<20, 21, 22, 23>>,
    Topic = <<"TR">>,
    send_publish_msg_short_topic(Socket, QoS, MsgId1, Topic, Payload1),
    timer:sleep(100),

    Eexp = <<11, ?SN_PUBLISH, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1, ?SN_SHORT_TOPIC:2, Topic/binary, (mid(0)):16, <<20, 21, 22, 23>>/binary>>,
    What = receive_response(Socket),
    ?assertEqual(Eexp, What),

    send_disconnect_msg(Socket, undefined),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),
    gen_udp:close(Socket).

publish_qos0_test5(_Config) ->
    Dup = 0,
    QoS = 0,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    MsgId = 1,
    TopicId0 = 0,
    {ok, Socket} = gen_udp:open(0, [binary]),
    send_connect_msg(Socket, <<"test">>),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),
    send_subscribe_msg_short_topic(Socket, QoS, <<"/#">>, MsgId),
    ?assertEqual(<<8, ?SN_SUBACK, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1, ?SN_NORMAL_TOPIC:2, TopicId0:16, MsgId:16, ?SN_RC_ACCEPTED>>,
        receive_response(Socket)),
    send_disconnect_msg(Socket, undefined),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),

    gen_udp:close(Socket).


publish_qos0_test6(_Config) ->
    Dup = 0,
    QoS = 0,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    MsgId = 1,
    TopicId1 = ?MAX_PRED_TOPIC_ID + 1,
    {ok, Socket} = gen_udp:open(0, [binary]),
    send_connect_msg(Socket, <<"test">>),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),

    Topic = <<"abc">>,
    send_subscribe_msg_normal_topic(Socket, QoS, Topic, MsgId),
    ?assertEqual(<<8, ?SN_SUBACK, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1, ?SN_NORMAL_TOPIC:2, TopicId1:16, MsgId:16, ?SN_RC_ACCEPTED>>,
        receive_response(Socket)),

    MsgId1 = 3,
    Payload1 = <<20, 21, 22, 23>>,
    send_publish_msg_normal_topic(Socket, QoS, MsgId1, TopicId1, Payload1),
    timer:sleep(100),

    Eexp = <<11, ?SN_PUBLISH, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1, ?SN_NORMAL_TOPIC:2, TopicId1:16, (mid(0)):16, <<20, 21, 22, 23>>/binary>>,
    What = receive_response(Socket),
    ?assertEqual(Eexp, What),

    send_disconnect_msg(Socket, undefined),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),
    gen_udp:close(Socket).

publish_qos1_test1(_Config) ->
    Dup = 0,
    QoS = 1,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    MsgId = 1,
    TopicId1 = ?MAX_PRED_TOPIC_ID + 1,
    Topic = <<"abc">>,
    {ok, Socket} = gen_udp:open(0, [binary]),
    send_connect_msg(Socket, <<"test">>),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),
    send_subscribe_msg_normal_topic(Socket, QoS, Topic, MsgId),
    ?assertEqual(<<8, ?SN_SUBACK, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1,
                   ?SN_NORMAL_TOPIC:2, TopicId1:16, MsgId:16, ?SN_RC_ACCEPTED>>,
                 receive_response(Socket)),

    Payload1 = <<20, 21, 22, 23>>,
    send_publish_msg_normal_topic(Socket, QoS, MsgId, TopicId1, Payload1),
    ?assertEqual(<<7, ?SN_PUBACK, TopicId1:16, MsgId:16, ?SN_RC_ACCEPTED>>, receive_response(Socket)),
    timer:sleep(100),

    ?assertEqual(<<11, ?SN_PUBLISH, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1, ?SN_NORMAL_TOPIC:2, TopicId1:16, MsgId:16, <<20, 21, 22, 23>>/binary>>, receive_response(Socket)),

    send_disconnect_msg(Socket, undefined),
    gen_udp:close(Socket).

publish_qos1_test2(_Config) ->
    Dup = 0,
    QoS = 1,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    MsgId = 1,
    PredefTopicId = ?PREDEF_TOPIC_ID1,
    {ok, Socket} = gen_udp:open(0, [binary]),
    send_connect_msg(Socket, <<"test">>),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),

    send_subscribe_msg_predefined_topic(Socket, QoS, PredefTopicId, MsgId),
    ?assertEqual(<<8, ?SN_SUBACK, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1, ?SN_NORMAL_TOPIC:2, PredefTopicId:16, MsgId:16, ?SN_RC_ACCEPTED>>,
        receive_response(Socket)),

    Payload1 = <<20, 21, 22, 23>>,
    send_publish_msg_predefined_topic(Socket, QoS, MsgId, PredefTopicId, Payload1),
    ?assertEqual(<<7, ?SN_PUBACK, PredefTopicId:16, MsgId:16, ?SN_RC_ACCEPTED>>, receive_response(Socket)),
    timer:sleep(100),

    send_disconnect_msg(Socket, undefined),
    gen_udp:close(Socket).

publish_qos1_test3(_Config) ->
    QoS = 1,
    MsgId = 1,
    TopicId5 = 5,
    {ok, Socket} = gen_udp:open(0, [binary]),
    send_connect_msg(Socket, <<"test">>),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),
    send_publish_msg_predefined_topic(Socket, QoS, MsgId, tid(5), <<20, 21, 22, 23>>),
    ?assertEqual(<<7, ?SN_PUBACK, TopicId5:16, MsgId:16, ?SN_RC_INVALID_TOPIC_ID>>, receive_response(Socket)),

    send_disconnect_msg(Socket, undefined),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),
    gen_udp:close(Socket).

publish_qos1_test4(_Config) ->
    Dup = 0,
    QoS = 1,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    MsgId = 7,
    TopicId0 = 0,
    {ok, Socket} = gen_udp:open(0, [binary]),
    send_connect_msg(Socket, <<"test">>),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),
    send_subscribe_msg_short_topic(Socket, QoS, <<"ab">>, MsgId),
    ?assertEqual(<<8, ?SN_SUBACK, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1,
                   ?SN_NORMAL_TOPIC:2, TopicId0:16, MsgId:16, ?SN_RC_ACCEPTED>>,
                 receive_response(Socket)),

    Topic = <<"ab">>,
    Payload1 = <<20, 21, 22, 23>>,
    send_publish_msg_short_topic(Socket, QoS, MsgId, Topic, Payload1),
    <<TopicIdShort:16>> = Topic,
    ?assertEqual(<<7, ?SN_PUBACK, TopicIdShort:16, MsgId:16, ?SN_RC_ACCEPTED>>, receive_response(Socket)),
    timer:sleep(100),

    send_disconnect_msg(Socket, undefined),
    gen_udp:close(Socket).

publish_qos1_test5(_Config) ->
    Dup = 0,
    QoS = 1,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    MsgId = 7,
    TopicId1 = ?MAX_PRED_TOPIC_ID + 1,
    {ok, Socket} = gen_udp:open(0, [binary]),
    send_connect_msg(Socket, <<"test">>),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),

    send_subscribe_msg_normal_topic(Socket, QoS, <<"ab">>, MsgId),
    ?assertEqual(<<8, ?SN_SUBACK, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1,
                   ?SN_NORMAL_TOPIC:2, TopicId1:16, MsgId:16, ?SN_RC_ACCEPTED>>,
                 receive_response(Socket)),

    send_publish_msg_short_topic(Socket, QoS, MsgId, <<"/#">>, <<20, 21, 22, 23>>),
    <<TopicIdShort:16>> = <<"/#">>,
    ?assertEqual(<<7, ?SN_PUBACK, TopicIdShort:16, MsgId:16, ?SN_RC_NOT_SUPPORTED>>, receive_response(Socket)),

    send_disconnect_msg(Socket, undefined),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),
    gen_udp:close(Socket).

publish_qos1_test6(_Config) ->
    Dup = 0,
    QoS = 1,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    MsgId = 7,
    TopicId1 = ?MAX_PRED_TOPIC_ID + 1,
    {ok, Socket} = gen_udp:open(0, [binary]),
    send_connect_msg(Socket, <<"test">>),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),

    send_subscribe_msg_normal_topic(Socket, QoS, <<"ab">>, MsgId),
    ?assertEqual(<<8, ?SN_SUBACK, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1,
                   ?SN_NORMAL_TOPIC:2, TopicId1:16, MsgId:16, ?SN_RC_ACCEPTED>>,
                 receive_response(Socket)),

    send_publish_msg_short_topic(Socket, QoS, MsgId, <<"/+">>, <<20, 21, 22, 23>>),
    <<TopicIdShort:16>> = <<"/+">>,
    ?assertEqual(<<7, ?SN_PUBACK, TopicIdShort:16, MsgId:16, ?SN_RC_NOT_SUPPORTED>>, receive_response(Socket)),

    send_disconnect_msg(Socket, undefined),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),
    gen_udp:close(Socket).

publish_qos2_test1(_Config) ->
    Dup = 0,
    QoS = 2,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    MsgId = 7,
    TopicId1 = ?MAX_PRED_TOPIC_ID + 1,
    Topic = <<"/abc">>,
    {ok, Socket} = gen_udp:open(0, [binary]),
    send_connect_msg(Socket, <<"test">>),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),
    send_subscribe_msg_normal_topic(Socket, QoS, Topic, MsgId),
    ?assertEqual(<<8, ?SN_SUBACK, ?FNU:1, QoS:2, ?FNU:5, TopicId1:16, MsgId:16,
                   ?SN_RC_ACCEPTED>>, receive_response(Socket)),
    Payload1 = <<20, 21, 22, 23>>,

    send_publish_msg_normal_topic(Socket, QoS, MsgId, TopicId1, Payload1),
    ?assertEqual(<<4, ?SN_PUBREC, MsgId:16>>, receive_response(Socket)),
    send_pubrel_msg(Socket, MsgId),
    ?assertEqual(<<11, ?SN_PUBLISH, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1, ?SN_NORMAL_TOPIC:2, TopicId1:16, 1:16, <<20, 21, 22, 23>>/binary>>, receive_response(Socket)),
    ?assertEqual(<<4, ?SN_PUBCOMP, MsgId:16>>, receive_response(Socket)),
    timer:sleep(100),

    send_disconnect_msg(Socket, undefined),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),
    gen_udp:close(Socket).

publish_qos2_test2(_Config) ->
    Dup = 0,
    QoS = 2,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    MsgId = 7,
    PredefTopicId = ?PREDEF_TOPIC_ID2,
    {ok, Socket} = gen_udp:open(0, [binary]),
    send_connect_msg(Socket, <<"test">>),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),

    send_subscribe_msg_predefined_topic(Socket, QoS, PredefTopicId, MsgId),
    ?assertEqual(<<8, ?SN_SUBACK, ?FNU:1, QoS:2, ?FNU:5, PredefTopicId:16, MsgId:16, ?SN_RC_ACCEPTED>>,
        receive_response(Socket)),

    Payload1 = <<20, 21, 22, 23>>,
    send_publish_msg_predefined_topic(Socket, QoS, MsgId, PredefTopicId, Payload1),
    ?assertEqual(<<4, ?SN_PUBREC, MsgId:16>>, receive_response(Socket)),
    send_pubrel_msg(Socket, MsgId),

    ?assertEqual(<<11, ?SN_PUBLISH, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1, ?SN_PREDEFINED_TOPIC :2, PredefTopicId:16, 1:16, <<20, 21, 22, 23>>/binary>>, receive_response(Socket)),
    ?assertEqual(<<4, ?SN_PUBCOMP, MsgId:16>>, receive_response(Socket)),

    timer:sleep(100),

    send_disconnect_msg(Socket, undefined),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),
    gen_udp:close(Socket).

publish_qos2_test3(_Config) ->
    Dup = 0,
    QoS = 2,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    MsgId = 7,
    TopicId0 = 0,
    {ok, Socket} = gen_udp:open(0, [binary]),
    send_connect_msg(Socket, <<"test">>),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),

    send_subscribe_msg_normal_topic(Socket, QoS, <<"/#">>, MsgId),
    ?assertEqual(<<8, ?SN_SUBACK, ?FNU:1, QoS:2, ?FNU:5, TopicId0:16, MsgId:16, ?SN_RC_ACCEPTED>>,
        receive_response(Socket)),

    Payload1 = <<20, 21, 22, 23>>,
    send_publish_msg_short_topic(Socket, QoS, MsgId, <<"/a">>, Payload1),
    ?assertEqual(<<4, ?SN_PUBREC, MsgId:16>>, receive_response(Socket)),
    send_pubrel_msg(Socket, MsgId),

    ?assertEqual(<<11, ?SN_PUBLISH, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1, ?SN_SHORT_TOPIC :2, <<"/a">>/binary, 1:16, <<20, 21, 22, 23>>/binary>>, receive_response(Socket)),
    ?assertEqual(<<4, ?SN_PUBCOMP, MsgId:16>>, receive_response(Socket)),
    timer:sleep(100),

    send_disconnect_msg(Socket, undefined),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),
    gen_udp:close(Socket).

will_test1(_Config) ->
    QoS = 1,
    Duration = 1,
    {ok, Socket} = gen_udp:open(0, [binary]),
    ClientId = <<"test">>,
    send_connect_msg_with_will(Socket, Duration, ClientId),
    ?assertEqual(<<2, ?SN_WILLTOPICREQ>>, receive_response(Socket)),

    send_willtopic_msg(Socket, <<"abc">>, QoS),
    ?assertEqual(<<2, ?SN_WILLMSGREQ>>, receive_response(Socket)),

    send_willmsg_msg(Socket, <<10, 11, 12, 13, 14>>),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),

    send_pingreq_msg(Socket, undefined),
    ?assertEqual(<<2, ?SN_PINGRESP>>, receive_response(Socket)),

    % wait udp client keepalive timeout
    timer:sleep(10000),

    receive_response(Socket), % ignore PUBACK

    send_disconnect_msg(Socket, undefined),
    ?assertEqual(udp_receive_timeout, receive_response(Socket)),

    gen_udp:close(Socket).

will_test2(_Config) ->
    QoS = 2,
    Duration = 1,
    {ok, Socket} = gen_udp:open(0, [binary]),

    ClientId = <<"test">>,
    send_connect_msg_with_will(Socket, Duration, ClientId),
    ?assertEqual(<<2, ?SN_WILLTOPICREQ>>, receive_response(Socket)),
    send_willtopic_msg(Socket, <<"goodbye">>, QoS),
    ?assertEqual(<<2, ?SN_WILLMSGREQ>>, receive_response(Socket)),
    send_willmsg_msg(Socket, <<10, 11, 12, 13, 14>>),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),
    send_pingreq_msg(Socket, undefined),
    ?assertEqual(<<2, ?SN_PINGRESP>>, receive_response(Socket)),

    timer:sleep(10000),

    receive_response(Socket), % ignore PUBACK
    receive_response(Socket), % ignore PUBCOMP

    send_disconnect_msg(Socket, undefined),
    ?assertEqual(udp_receive_timeout, receive_response(Socket)),

    gen_udp:close(Socket).

will_test3(_Config) ->
    Duration = 1,
    {ok, Socket} = gen_udp:open(0, [binary]),

    ClientId = <<"test">>,
    send_connect_msg_with_will(Socket, Duration, ClientId),
    ?assertEqual(<<2, ?SN_WILLTOPICREQ>>, receive_response(Socket)),
    send_willtopic_empty_msg(Socket),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),
    send_pingreq_msg(Socket, undefined),
    ?assertEqual(<<2, ?SN_PINGRESP>>, receive_response(Socket)),

    timer:sleep(10000),

    ?assertEqual(udp_receive_timeout, receive_response(Socket)),

    send_disconnect_msg(Socket, undefined),
    ?assertEqual(udp_receive_timeout, receive_response(Socket)),

    gen_udp:close(Socket).

will_test4(_Config) ->
    QoS = 1,
    Duration = 1,
    {ok, Socket} = gen_udp:open(0, [binary]),

    ClientId = <<"test">>,
    send_connect_msg_with_will(Socket, Duration, ClientId),
    ?assertEqual(<<2, ?SN_WILLTOPICREQ>>, receive_response(Socket)),
    send_willtopic_msg(Socket, <<"abc">>, QoS),
    ?assertEqual(<<2, ?SN_WILLMSGREQ>>, receive_response(Socket)),
    send_willmsg_msg(Socket, <<10, 11, 12, 13, 14>>),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),
    send_pingreq_msg(Socket, undefined),
    ?assertEqual(<<2, ?SN_PINGRESP>>, receive_response(Socket)),
    send_willtopicupd_msg(Socket, <<"/XYZ">>, ?QOS_1),
    ?assertEqual(<<3, ?SN_WILLTOPICRESP, ?SN_RC_ACCEPTED>>, receive_response(Socket)),
    send_willmsgupd_msg(Socket, <<"1A2B3C">>),
    ?assertEqual(<<3, ?SN_WILLMSGRESP, ?SN_RC_ACCEPTED>>, receive_response(Socket)),

    timer:sleep(10000),

    receive_response(Socket), % ignore PUBACK

    send_disconnect_msg(Socket, undefined),
    ?assertEqual(udp_receive_timeout, receive_response(Socket)),

    gen_udp:close(Socket).

will_test5(_Config) ->
    QoS = 1,
    Duration = 1,
    {ok, Socket} = gen_udp:open(0, [binary]),

    ClientId = <<"test">>,
    send_connect_msg_with_will(Socket, Duration, ClientId),
    ?assertEqual(<<2, ?SN_WILLTOPICREQ>>, receive_response(Socket)),
    send_willtopic_msg(Socket, <<"abc">>, QoS),
    ?assertEqual(<<2, ?SN_WILLMSGREQ>>, receive_response(Socket)),
    send_willmsg_msg(Socket, <<10, 11, 12, 13, 14>>),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),
    send_pingreq_msg(Socket, undefined),
    ?assertEqual(<<2, ?SN_PINGRESP>>, receive_response(Socket)),
    send_willtopicupd_empty_msg(Socket),
    ?assertEqual(<<3, ?SN_WILLTOPICRESP, ?SN_RC_ACCEPTED>>, receive_response(Socket)),

    timer:sleep(1000),

    ?assertEqual(udp_receive_timeout, receive_response(Socket)),

    send_disconnect_msg(Socket, undefined),
    ?assertEqual(udp_receive_timeout, receive_response(Socket)),

    gen_udp:close(Socket).

asleep_test01_timeout(_Config) ->
    QoS = 1,
    Duration = 1,
    WillTopic = <<"dead">>,
    WillPayload = <<10, 11, 12, 13, 14>>,
    {ok, Socket} = gen_udp:open(0, [binary]),

    ClientId = <<"test">>,
    send_connect_msg_with_will(Socket, Duration, ClientId),
    ?assertEqual(<<2, ?SN_WILLTOPICREQ>>, receive_response(Socket)),
    send_willtopic_msg(Socket, WillTopic, QoS),
    ?assertEqual(<<2, ?SN_WILLMSGREQ>>, receive_response(Socket)),
    send_willmsg_msg(Socket, WillPayload),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),

    send_disconnect_msg(Socket, 1),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),

    %% asleep timer should get timeout, and device is lost
    timer:sleep(3000),

    gen_udp:close(Socket).

asleep_test02_to_awake_and_back(_Config) ->
    QoS = 1,
    Keepalive_Duration = 1,
    SleepDuration = 5,
    WillTopic = <<"dead">>,
    WillPayload = <<10, 11, 12, 13, 14>>,
    {ok, Socket} = gen_udp:open(0, [binary]),

    ClientId = <<"test">>,
    send_connect_msg_with_will(Socket, Keepalive_Duration, ClientId),
    ?assertEqual(<<2, ?SN_WILLTOPICREQ>>, receive_response(Socket)),
    send_willtopic_msg(Socket, WillTopic, QoS),
    ?assertEqual(<<2, ?SN_WILLMSGREQ>>, receive_response(Socket)),
    send_willmsg_msg(Socket, WillPayload),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),

    % goto asleep state
    send_disconnect_msg(Socket, SleepDuration),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),

    timer:sleep(4500),

    % goto awake state and back
    send_pingreq_msg(Socket, <<"test">>),
    ?assertEqual(<<2, ?SN_PINGRESP>>, receive_response(Socket)),

    timer:sleep(4500),

    % goto awake state and back
    send_pingreq_msg(Socket, <<"test">>),
    ?assertEqual(<<2, ?SN_PINGRESP>>, receive_response(Socket)),

    %% during above procedure, mqtt keepalive timer should not terminate mqtt-sn process

    %% asleep timer should get timeout, and device should get lost
    timer:sleep(8000),

    gen_udp:close(Socket).

asleep_test03_to_awake_qos1_dl_msg(_Config) ->
    QoS = 1,
    Duration = 1,
    WillTopic = <<"dead">>,
    WillPayload = <<10, 11, 12, 13, 14>>,
    MsgId = 1000,
    {ok, Socket} = gen_udp:open(0, [binary]),
    ClientId = <<"test">>,
    send_connect_msg_with_will(Socket, Duration, ClientId),
    ?assertEqual(<<2, ?SN_WILLTOPICREQ>>, receive_response(Socket)),
    send_willtopic_msg(Socket, WillTopic, QoS),
    ?assertEqual(<<2, ?SN_WILLMSGREQ>>, receive_response(Socket)),
    send_willmsg_msg(Socket, WillPayload),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),

    % subscribe
    TopicName1 = <<"abc">>,
    MsgId1 = 25,
    TopicId1 = ?MAX_PRED_TOPIC_ID + 1,
    WillBit = 0,
    Dup = 0,
    Retain = 0,
    CleanSession = 0,
    ReturnCode = 0,
    Payload1 = <<55, 66, 77, 88, 99>>,
    MsgId2 = 87,

    send_register_msg(Socket, TopicName1, MsgId1),
    ?assertEqual(<<7, ?SN_REGACK, TopicId1:16, MsgId1:16, 0:8>>, receive_response(Socket)),
    send_subscribe_msg_predefined_topic(Socket, QoS, TopicId1, MsgId),
    ?assertEqual(<<8, ?SN_SUBACK, Dup:1, QoS:2, Retain:1, WillBit:1, CleanSession:1, ?SN_NORMAL_TOPIC:2, TopicId1:16, MsgId:16, ReturnCode>>,
        receive_response(Socket)),


    % goto asleep state
    send_disconnect_msg(Socket, 1),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),

    timer:sleep(300),

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% send downlink data in asleep state. This message should be send to device once it wake up
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    send_publish_msg_predefined_topic(Socket, QoS, MsgId2, TopicId1, Payload1),

    {ok, C} = emqx_client:start_link(),
    {ok, _} = emqx_client:connect(C),
    {ok, _} = emqx_client:publish(C, TopicName1, Payload1, QoS),
    ok = emqx_client:disconnect(C),

    timer:sleep(50),

    % goto awake state, receive downlink messages, and go back to asleep
    send_pingreq_msg(Socket, <<"test">>),
    
    %% {unexpected_udp_data, _} = receive_response(Socket),

    %% ct:log("Response Data: ~p", [receive_response(Socket)]),
    %% ct:log("ReceiveData 2: ~p", [receive_response(Socket)]),
    %% ct:log("ReceiveData 3: ~p", [receive_response(Socket)]),        
    UdpData = receive_response(Socket),
    MsgId_udp = check_publish_msg_on_udp({Dup, QoS, Retain, WillBit, CleanSession, ?SN_NORMAL_TOPIC, TopicId1, Payload1}, UdpData),
    send_puback_msg(Socket, TopicId1, MsgId_udp),

    ?assertEqual(<<2, ?SN_PINGRESP>>, receive_response(Socket)),

    gen_udp:close(Socket).

asleep_test04_to_awake_qos1_dl_msg(_Config) ->
    QoS = 1,
    Duration = 1,
    WillTopic = <<"dead">>,
    WillPayload = <<10, 11, 12, 13, 14>>,
    {ok, Socket} = gen_udp:open(0, [binary]),
    ClientId = <<"test">>,
    send_connect_msg_with_will(Socket, Duration, ClientId),
    ?assertEqual(<<2, ?SN_WILLTOPICREQ>>, receive_response(Socket)),
    send_willtopic_msg(Socket, WillTopic, QoS),
    ?assertEqual(<<2, ?SN_WILLMSGREQ>>, receive_response(Socket)),
    send_willmsg_msg(Socket, WillPayload),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),

    % subscribe
    TopicName1 = <<"a/+/c">>,
    MsgId1 = 25,
    TopicId0 = 0,
    WillBit = 0,
    Dup = 0,
    Retain = 0,
    CleanSession = 0,
    ReturnCode = 0,
    send_subscribe_msg_normal_topic(Socket, QoS, TopicName1, MsgId1),
    ?assertEqual(<<8, ?SN_SUBACK, Dup:1, QoS:2, Retain:1, WillBit:1, CleanSession:1, ?SN_NORMAL_TOPIC:2, TopicId0:16, MsgId1:16, ReturnCode>>,
        receive_response(Socket)),

    % goto asleep state
    send_disconnect_msg(Socket, 1),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),

    timer:sleep(300),

    %% send downlink data in asleep state. This message should be send to device once it wake up
    Payload1 = <<55, 66, 77, 88, 99>>,

    {ok, C} = emqx_client:start_link(),
    {ok, _} = emqx_client:connect(C),
    {ok, _} = emqx_client:publish(C, <<"a/b/c">>, Payload1, QoS),
    ok = emqx_client:disconnect(C),

    timer:sleep(300),

    % goto awake state, receive downlink messages, and go back to asleep
    send_pingreq_msg(Socket, <<"test">>),

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% get REGISTER first, since this topic has never been registered
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    UdpData2 = receive_response(Socket),
    {TopicIdNew, MsgId3} = check_register_msg_on_udp(<<"a/b/c">>, UdpData2),
    send_regack_msg(Socket, TopicIdNew, MsgId3),

    UdpData = receive_response(Socket),
    MsgId_udp = check_publish_msg_on_udp({Dup, QoS, Retain, WillBit, CleanSession, ?SN_NORMAL_TOPIC, TopicIdNew, Payload1}, UdpData),
    send_puback_msg(Socket, TopicIdNew, MsgId_udp),

    ?assertEqual(<<2, ?SN_PINGRESP>>, receive_response(Socket)),

    gen_udp:close(Socket).

asleep_test05_to_awake_qos1_dl_msg(_Config) ->
    QoS = 1,
    Duration = 10,
    WillTopic = <<"dead">>,
    WillPayload = <<10, 11, 12, 13, 14>>,
    {ok, Socket} = gen_udp:open(0, [binary]),
    ClientId = <<"test">>,
    send_connect_msg_with_will(Socket, Duration, ClientId),
    ?assertEqual(<<2, ?SN_WILLTOPICREQ>>, receive_response(Socket)),
    send_willtopic_msg(Socket, WillTopic, QoS),
    ?assertEqual(<<2, ?SN_WILLMSGREQ>>, receive_response(Socket)),
    send_willmsg_msg(Socket, WillPayload),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),

    % subscribe
    TopicName1 = <<"u/+/w">>,
    MsgId1 = 25,
    TopicId0 = 0,
    WillBit = 0,
    Dup = 0,
    Retain = 0,
    CleanSession = 0,
    ReturnCode = 0,
    send_subscribe_msg_normal_topic(Socket, QoS, TopicName1, MsgId1),
    ?assertEqual(<<8, ?SN_SUBACK, Dup:1, QoS:2, Retain:1, WillBit:1, CleanSession:1, ?SN_NORMAL_TOPIC:2, TopicId0:16, MsgId1:16, ReturnCode>>,
        receive_response(Socket)),

    % goto asleep state
    SleepDuration = 30,
    send_disconnect_msg(Socket, SleepDuration),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),

    timer:sleep(300),

    %% send downlink data in asleep state. This message should be send to device once it wake up
    Payload2 = <<55, 66, 77, 88, 99>>,
    Payload3 = <<61, 71, 81>>,
    Payload4 = <<100, 101, 102, 103, 104, 105, 106, 107>>,
    TopicName_test5 = <<"u/v/w">>,
    {ok, C} = emqx_client:start_link(),
    {ok, _} = emqx_client:connect(C),
    {ok, _} = emqx_client:publish(C, TopicName_test5, Payload2, QoS),
    {ok, _} = emqx_client:publish(C, TopicName_test5, Payload3, QoS),
    {ok, _} = emqx_client:publish(C, TopicName_test5, Payload4, QoS),
    ok = emqx_client:disconnect(C),
    timer:sleep(50),

    % goto awake state, receive downlink messages, and go back to asleep
    send_pingreq_msg(Socket, <<"test">>),

    UdpData_reg = receive_response(Socket),
    {TopicIdNew, MsgId_reg} = check_register_msg_on_udp(TopicName_test5, UdpData_reg),
    send_regack_msg(Socket, TopicIdNew, MsgId_reg),

    UdpData2 = receive_response(Socket),
    MsgId2 = check_publish_msg_on_udp({Dup, QoS, Retain, WillBit, CleanSession, ?SN_NORMAL_TOPIC, TopicIdNew, Payload2}, UdpData2),
    send_puback_msg(Socket, TopicIdNew, MsgId2),
    timer:sleep(50),

    UdpData3 = receive_response(Socket),
    MsgId3 = check_publish_msg_on_udp({Dup, QoS, Retain, WillBit, CleanSession, ?SN_NORMAL_TOPIC, TopicIdNew, Payload3}, UdpData3),
    send_puback_msg(Socket, TopicIdNew, MsgId3),
    timer:sleep(50),

    case receive_response(Socket) of
        <<2,23>> -> ok;
        UdpData4 ->
            MsgId4 = check_publish_msg_on_udp({Dup, QoS, Retain, WillBit,
                                               CleanSession, ?SN_NORMAL_TOPIC,
                                               TopicIdNew, Payload4}, UdpData4),
            send_puback_msg(Socket, TopicIdNew, MsgId4)
    end,
    timer:sleep(50),
    gen_udp:close(Socket).

asleep_test06_to_awake_qos2_dl_msg(_Config) ->
    QoS = 2,
    Duration = 1,
    WillTopic = <<"dead">>,
    WillPayload = <<10, 11, 12, 13, 14>>,
    {ok, Socket} = gen_udp:open(0, [binary]),
    ClientId = <<"test">>,
    send_connect_msg_with_will(Socket, Duration, ClientId),
    ?assertEqual(<<2, ?SN_WILLTOPICREQ>>, receive_response(Socket)),
    send_willtopic_msg(Socket, WillTopic, QoS),
    ?assertEqual(<<2, ?SN_WILLMSGREQ>>, receive_response(Socket)),
    send_willmsg_msg(Socket, WillPayload),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),

    % subscribe
    TopicName_tom = <<"tom">>,
    MsgId1 = 25,
    WillBit = 0,
    Dup = 0,
    Retain = 0,
    CleanSession = 0,
    ReturnCode = 0,
    send_register_msg(Socket, TopicName_tom, MsgId1),
    TopicId_tom = check_regack_msg_on_udp(MsgId1, receive_response(Socket)),
    send_subscribe_msg_predefined_topic(Socket, QoS, TopicId_tom, MsgId1),
    ?assertEqual(<<8, ?SN_SUBACK, Dup:1, QoS:2, Retain:1, WillBit:1, CleanSession:1,
                   ?SN_NORMAL_TOPIC:2, TopicId_tom:16, MsgId1:16, ReturnCode>>,
                 receive_response(Socket)),

    % goto asleep state
    SleepDuration = 11,
    send_disconnect_msg(Socket, SleepDuration),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),

    timer:sleep(100),

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% send downlink data in asleep state. This message should be send to device once it wake up
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    Payload1 = <<55, 66, 77, 88, 99>>,
    {ok, C} = emqx_client:start_link(),
    {ok, _} = emqx_client:connect(C),
    {ok, _} = emqx_client:publish(C, TopicName_tom, Payload1, QoS),
    ok = emqx_client:disconnect(C),
    timer:sleep(300),

    % goto awake state, receive downlink messages, and go back to asleep
    send_pingreq_msg(Socket, <<"test">>),

    UdpData = receive_response(Socket),
    MsgId_udp = check_publish_msg_on_udp({Dup, QoS, Retain, WillBit, CleanSession, ?SN_NORMAL_TOPIC, TopicId_tom, Payload1}, UdpData),
    send_pubrec_msg(Socket, MsgId_udp),

    timer:sleep(300),

    ?assertEqual(<<2, ?SN_PINGRESP>>, receive_response(Socket)),

    gen_udp:close(Socket).

asleep_test07_to_connected(_Config) ->
    QoS = 1,
    Keepalive_Duration = 10,
    SleepDuration = 1,
    WillTopic = <<"dead">>,
    WillPayload = <<10, 11, 12, 13, 14>>,
    {ok, Socket} = gen_udp:open(0, [binary]),
    ClientId = <<"test">>,
    send_connect_msg_with_will(Socket, Keepalive_Duration, ClientId),
    ?assertEqual(<<2, ?SN_WILLTOPICREQ>>, receive_response(Socket)),
    send_willtopic_msg(Socket, WillTopic, QoS),
    ?assertEqual(<<2, ?SN_WILLMSGREQ>>, receive_response(Socket)),
    send_willmsg_msg(Socket, WillPayload),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),

    % subscribe
    TopicName_tom = <<"tom">>,
    MsgId1 = 25,
    WillBit = 0,
    Dup = 0,
    Retain = 0,
    CleanSession = 0,
    ReturnCode = 0,
    send_register_msg(Socket, TopicName_tom, MsgId1),
    TopicId_tom = check_regack_msg_on_udp(MsgId1, receive_response(Socket)),
    send_subscribe_msg_predefined_topic(Socket, QoS, TopicId_tom, MsgId1),
    ?assertEqual(<<8, ?SN_SUBACK, Dup:1, QoS:2, Retain:1, WillBit:1, CleanSession:1, ?SN_NORMAL_TOPIC:2, TopicId_tom:16, MsgId1:16, ReturnCode>>,
        receive_response(Socket)),

    % goto asleep state
    send_disconnect_msg(Socket, SleepDuration),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),

    timer:sleep(100),

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% send connect message, and goto connected state
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    send_connect_msg(Socket, ClientId),
    ?assertEqual(<<3, ?SN_CONNACK, ?SN_RC_ACCEPTED>>, receive_response(Socket)),

    timer:sleep(1500),
    % asleep timer should get timeout, without any effect

    timer:sleep(9000),
    % keepalive timer should get timeout

    gen_udp:close(Socket).

asleep_test08_to_disconnected(_Config) ->
    QoS = 1,
    Keepalive_Duration = 3,
    SleepDuration = 1,
    WillTopic = <<"dead">>,
    WillPayload = <<10, 11, 12, 13, 14>>,
    {ok, Socket} = gen_udp:open(0, [binary]),
    ClientId = <<"test">>,
    send_connect_msg_with_will(Socket, Keepalive_Duration, ClientId),
    ?assertEqual(<<2, ?SN_WILLTOPICREQ>>, receive_response(Socket)),
    send_willtopic_msg(Socket, WillTopic, QoS),
    ?assertEqual(<<2, ?SN_WILLMSGREQ>>, receive_response(Socket)),
    send_willmsg_msg(Socket, WillPayload),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),

    % goto asleep state
    send_disconnect_msg(Socket, SleepDuration),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),

    timer:sleep(100),

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% send disconnect message, and goto disconnected state
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    send_disconnect_msg(Socket, undefined),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),

    timer:sleep(100),
    % it is a normal termination, without will message

    gen_udp:close(Socket).

asleep_test09_to_awake_again_qos1_dl_msg(_Config) ->
    QoS = 1,
    Duration = 20,
    WillTopic = <<"dead">>,
    WillPayload = <<10, 11, 12, 13, 14>>,
    {ok, Socket} = gen_udp:open(0, [binary]),
    ClientId = <<"test">>,
    send_connect_msg_with_will(Socket, Duration, ClientId),
    ?assertEqual(<<2, ?SN_WILLTOPICREQ>>, receive_response(Socket)),
    send_willtopic_msg(Socket, WillTopic, QoS),
    ?assertEqual(<<2, ?SN_WILLMSGREQ>>, receive_response(Socket)),
    send_willmsg_msg(Socket, WillPayload),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),

    % subscribe
    TopicName1 = <<"u/+/w">>,
    MsgId1 = 25,
    TopicId0 = 0,
    WillBit = 0,
    Dup = 0,
    Retain = 0,
    CleanSession = 0,
    ReturnCode = 0,
    send_subscribe_msg_normal_topic(Socket, QoS, TopicName1, MsgId1),
    ?assertEqual(<<8, ?SN_SUBACK, Dup:1, QoS:2, Retain:1, WillBit:1, CleanSession:1, ?SN_NORMAL_TOPIC:2, TopicId0:16, MsgId1:16, ReturnCode>>,
        receive_response(Socket)),

    % goto asleep state
    SleepDuration = 30,
    send_disconnect_msg(Socket, SleepDuration),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),

    timer:sleep(300),

    %% send downlink data in asleep state. This message should be send to device once it wake up
    Payload2 = <<55, 66, 77, 88, 99>>,
    Payload3 = <<61, 71, 81>>,
    Payload4 = <<100, 101, 102, 103, 104, 105, 106, 107>>,
    TopicName_test9 = <<"u/v/w">>,
    {ok, C} = emqx_client:start_link(),
    {ok, _} = emqx_client:connect(C),
    {ok, _} = emqx_client:publish(C, TopicName_test9, Payload2, QoS),
    {ok, _} = emqx_client:publish(C, TopicName_test9, Payload3, QoS),
    {ok, _} = emqx_client:publish(C, TopicName_test9, Payload4, QoS),
    ok = emqx_client:disconnect(C),
    timer:sleep(300),

    % goto awake state, receive downlink messages, and go back to asleep
    send_pingreq_msg(Socket, <<"test">>),

    UdpData_reg = receive_response(Socket),
    {TopicIdNew, MsgId_reg} = check_register_msg_on_udp(TopicName_test9, UdpData_reg),
    send_regack_msg(Socket, TopicIdNew, MsgId_reg),

    UdpData2 = receive_response(Socket),
    MsgId2 = check_publish_msg_on_udp({Dup, QoS, Retain, WillBit, CleanSession, ?SN_NORMAL_TOPIC, TopicIdNew, Payload2}, UdpData2),
    send_puback_msg(Socket, TopicIdNew, MsgId2),
    timer:sleep(50),

    UdpData3 = receive_response(Socket),
    MsgId3 = check_publish_msg_on_udp({Dup, QoS, Retain, WillBit, CleanSession, ?SN_NORMAL_TOPIC, TopicIdNew, Payload3}, UdpData3),
    send_puback_msg(Socket, TopicIdNew, MsgId3),
    timer:sleep(50),

    case receive_response(Socket) of
        <<2,23>> -> ok;
        UdpData4 ->
            MsgId4 = check_publish_msg_on_udp({Dup, QoS, Retain, WillBit,
                                               CleanSession, ?SN_NORMAL_TOPIC,
                                               TopicIdNew, Payload4}, UdpData4),
            send_puback_msg(Socket, TopicIdNew, MsgId4)
    end,
    timer:sleep(50),

    receive_response(Socket),

    %% send PINGREQ again to enter awake state
    send_pingreq_msg(Socket, <<"test">>),
    %% will not receive any buffered PUBLISH messages buffered before last awake, only receive PINGRESP here
    ?assertEqual(<<2, ?SN_PINGRESP>>, receive_response(Socket)),

    gen_udp:close(Socket).

awake_test01_to_connected(_Config) ->
    QoS = 1,
    Keepalive_Duration = 3,
    SleepDuration = 1,
    WillTopic = <<"dead">>,
    WillPayload = <<10, 11, 12, 13, 14>>,
    {ok, Socket} = gen_udp:open(0, [binary]),
    ClientId = <<"test">>,
    send_connect_msg_with_will(Socket, Keepalive_Duration, ClientId),
    ?assertEqual(<<2, ?SN_WILLTOPICREQ>>, receive_response(Socket)),
    send_willtopic_msg(Socket, WillTopic, QoS),
    ?assertEqual(<<2, ?SN_WILLMSGREQ>>, receive_response(Socket)),
    send_willmsg_msg(Socket, WillPayload),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),

    % goto asleep state
    send_disconnect_msg(Socket, SleepDuration),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),

    timer:sleep(100),

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% send connect message, and goto connected state
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    send_connect_msg(Socket, ClientId),
    ?assertEqual(<<3, ?SN_CONNACK, ?SN_RC_ACCEPTED>>, receive_response(Socket)),

    timer:sleep(1500),
    % asleep timer should get timeout

    timer:sleep(9000),
    % keepalive timer should get timeout
    gen_udp:close(Socket).

awake_test02_to_disconnected(_Config) ->
    QoS = 1,
    Keepalive_Duration = 3,
    SleepDuration = 1,
    WillTopic = <<"dead">>,
    WillPayload = <<10, 11, 12, 13, 14>>,
    {ok, Socket} = gen_udp:open(0, [binary]),
    ClientId = <<"test">>,
    send_connect_msg_with_will(Socket, Keepalive_Duration, ClientId),
    ?assertEqual(<<2, ?SN_WILLTOPICREQ>>, receive_response(Socket)),
    send_willtopic_msg(Socket, WillTopic, QoS),
    ?assertEqual(<<2, ?SN_WILLMSGREQ>>, receive_response(Socket)),
    send_willmsg_msg(Socket, WillPayload),
    ?assertEqual(<<3, ?SN_CONNACK, 0>>, receive_response(Socket)),


    % goto asleep state
    send_disconnect_msg(Socket, SleepDuration),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),

    timer:sleep(100),

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% send disconnect message, and goto disconnected state
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    send_disconnect_msg(Socket, undefined),
    ?assertEqual(<<2, ?SN_DISCONNECT>>, receive_response(Socket)),

    timer:sleep(100),
    % it is a normal termination, no will message will be send

    gen_udp:close(Socket).

broadcast_test1(_Config) ->
    {ok, Socket} = gen_udp:open( 0, [binary]),
    send_searchgw_msg(Socket),
    ?assertEqual(<<3, ?SN_GWINFO, 1>>, receive_response(Socket)),
    timer:sleep(600),
    gen_udp:close(Socket).

send_searchgw_msg(Socket) ->
    Length = 3,
    MsgType = ?SN_SEARCHGW,
    Radius = 0,
    ok = gen_udp:send(Socket, ?HOST, ?PORT, <<Length:8, MsgType:8, Radius:8>>).

send_connect_msg(Socket, ClientId) ->
    Length = 6 + byte_size(ClientId),
    MsgType = ?SN_CONNECT,
    Dup = 0,
    QoS = 0,
    Retain = 0,
    Will = 0,
    CleanSession = 1,
    TopicIdType = 0,
    ProtocolId = 1,
    Duration = 10,
    Packet = <<Length:8, MsgType:8, Dup:1, QoS:2, Retain:1, Will:1, CleanSession:1,
               TopicIdType:2, ProtocolId:8, Duration:16, ClientId/binary>>,
    ok = gen_udp:send(Socket, ?HOST, ?PORT, Packet).

send_connect_msg_with_will(Socket, Duration, ClientId) ->
    Length = 10,
    Will = 1,
    CleanSession = 1,
    ProtocolId = 1,
    ConnectPacket = <<Length:8, ?SN_CONNECT:8, ?FNU:4, Will:1, CleanSession:1,
                      ?FNU:2, ProtocolId:8, Duration:16, ClientId/binary>>,
    ok = gen_udp:send(Socket, ?HOST, ?PORT, ConnectPacket).

send_willtopic_msg(Socket, Topic, QoS) ->
    Length = 3+byte_size(Topic),
    MsgType = ?SN_WILLTOPIC,
    Retain = 0,
    WillTopicPacket = <<Length:8, MsgType:8, ?FNU:1, QoS:2, Retain:1, ?FNU:4, Topic/binary>>,
    ok = gen_udp:send(Socket, ?HOST, ?PORT, WillTopicPacket).

send_willtopic_empty_msg(Socket) ->
    Length = 2,
    MsgType = ?SN_WILLTOPIC,
    WillTopicPacket = <<Length:8, MsgType:8>>,
    ok = gen_udp:send(Socket, ?HOST, ?PORT, WillTopicPacket).

send_willmsg_msg(Socket, Msg) ->
    Length = 2+byte_size(Msg),
    WillMsgPacket = <<Length:8, ?SN_WILLMSG:8, Msg/binary>>,
    ok = gen_udp:send(Socket, ?HOST, ?PORT, WillMsgPacket).

send_willtopicupd_msg(Socket, Topic, QoS) ->
    Length = 3+byte_size(Topic),
    MsgType = ?SN_WILLTOPICUPD,
    Retain = 0,
    WillTopicPacket = <<Length:8, MsgType:8, ?FNU:1, QoS:2, Retain:1, ?FNU:4, Topic/binary>>,
    ok = gen_udp:send(Socket, ?HOST, ?PORT, WillTopicPacket).

send_willtopicupd_empty_msg(Socket) ->
    Length = 2,
    MsgType = ?SN_WILLTOPICUPD,
    WillTopicPacket = <<Length:8, MsgType:8>>,
    ok = gen_udp:send(Socket, ?HOST, ?PORT, WillTopicPacket).

send_willmsgupd_msg(Socket, Msg) ->
    Length = 2+byte_size(Msg),
    MsgType = ?SN_WILLMSGUPD,
    WillTopicPacket = <<Length:8, MsgType:8, Msg/binary>>,
    ok = gen_udp:send(Socket, ?HOST, ?PORT, WillTopicPacket).

send_register_msg(Socket, TopicName, MsgId) ->
    Length = 6 + byte_size(TopicName),
    MsgType = ?SN_REGISTER,
    TopicId = 0,
    RegisterPacket = <<Length:8, MsgType:8, TopicId:16, MsgId:16, TopicName/binary>>,
    ok = gen_udp:send(Socket, ?HOST, ?PORT, RegisterPacket).

send_regack_msg(Socket, TopicId, MsgId) ->
    Length = 7,
    MsgType = ?SN_REGACK,
    Packet = <<Length:8, MsgType:8, TopicId:16, MsgId:16, ?SN_RC_ACCEPTED>>,
    ok = gen_udp:send(Socket, ?HOST, ?PORT, Packet).

send_publish_msg_normal_topic(Socket, QoS, MsgId, TopicId, Data) ->
    Length = 7 + byte_size(Data),
    MsgType = ?SN_PUBLISH,
    Dup = 0,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    TopicIdType = ?SN_NORMAL_TOPIC,
    PublishPacket = <<Length:8, MsgType:8, Dup:1, QoS:2, Retain:1, Will:1,
        CleanSession:1, TopicIdType:2, TopicId:16, MsgId:16, Data/binary>>,
    ?LOG("send_publish_msg_normal_topic TopicId=~p, Data=~p", [TopicId, Data]),
    ok = gen_udp:send(Socket, ?HOST, ?PORT, PublishPacket).

send_publish_msg_predefined_topic(Socket, QoS, MsgId, TopicId, Data) ->
    Length = 7 + byte_size(Data),
    MsgType = ?SN_PUBLISH,
    Dup = 0,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    TopicIdType = ?SN_PREDEFINED_TOPIC,
    PublishPacket = <<Length:8, MsgType:8, Dup:1, QoS:2, Retain:1, Will:1,
                      CleanSession:1, TopicIdType:2, TopicId:16, MsgId:16, Data/binary>>,
    ?LOG("send_publish_msg_predefined_topic TopicId=~p, Data=~p", [TopicId, Data]),
    ok = gen_udp:send(Socket, ?HOST, ?PORT, PublishPacket).

send_publish_msg_short_topic(Socket, QoS, MsgId, TopicName, Data) ->
    Length = 7 + byte_size(Data),
    MsgType = ?SN_PUBLISH,
    Dup = 0,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    TopicIdType = 2,
    PublishPacket = <<Length:8, MsgType:8, Dup:1, QoS:2, Retain:1, Will:1,
                      CleanSession:1, TopicIdType:2, TopicName/binary, MsgId:16, Data/binary>>,
    ?LOG("send_publish_msg_short_topic TopicName=~p, Data=~p", [TopicName, Data]),
    ok = gen_udp:send(Socket, ?HOST, ?PORT, PublishPacket).

send_puback_msg(Socket, TopicId, MsgId) ->
    Length = 7,
    MsgType = ?SN_PUBACK,
    PubAckPacket = <<Length:8, MsgType:8, TopicId:16, MsgId:16, ?SN_RC_ACCEPTED:8>>,
    ?LOG("send_puback_msg TopicId=~p, MsgId=~p", [TopicId, MsgId]),
    ok = gen_udp:send(Socket, ?HOST, ?PORT, PubAckPacket).

send_pubrec_msg(Socket, MsgId) ->
    Length = 4,
    MsgType = ?SN_PUBREC,
    PubRecPacket = <<Length:8, MsgType:8, MsgId:16>>,
    ?LOG("send_pubrec_msg MsgId=~p", [MsgId]),
    ok = gen_udp:send(Socket, ?HOST, ?PORT, PubRecPacket).

send_pubrel_msg(Socket, MsgId) ->
    Length = 4,
    MsgType = ?SN_PUBREL,
    PubRelPacket = <<Length:8, MsgType:8, MsgId:16>>,
    ?LOG("send_pubrel_msg MsgId=~p", [MsgId]),
    ok = gen_udp:send(Socket, ?HOST, ?PORT, PubRelPacket).

send_pubcomp_msg(Socket, MsgId) ->
    Length = 4,
    MsgType = ?SN_PUBCOMP,
    PubCompPacket = <<Length:8, MsgType:8, MsgId:16>>,
    ?LOG("send_pubcomp_msg MsgId=~p", [MsgId]),
    ok = gen_udp:send(Socket, ?HOST, ?PORT, PubCompPacket).

send_subscribe_msg_normal_topic(Socket, QoS, Topic, MsgId) ->
    MsgType = ?SN_SUBSCRIBE,
    Dup = 0,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    TopicIdType = ?SN_NORMAL_TOPIC,
    Length = byte_size(Topic) + 5,
    SubscribePacket = <<Length:8, MsgType:8, Dup:1, QoS:2, Retain:1, Will:1,
                        CleanSession:1, TopicIdType:2, MsgId:16, Topic/binary>>,
    ?LOG("send_subscribe_msg_normal_topic Topic=~p, MsgId=~p", [Topic, MsgId]),
    ok = gen_udp:send(Socket, ?HOST, ?PORT, SubscribePacket).

send_subscribe_msg_predefined_topic(Socket, QoS, TopicId, MsgId) ->
    Length = 7,
    MsgType = ?SN_SUBSCRIBE,
    Dup = 0,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    TopicIdType = ?SN_PREDEFINED_TOPIC,
    SubscribePacket = <<Length:8, MsgType:8, Dup:1, QoS:2, Retain:1, Will:1,
        CleanSession:1, TopicIdType:2, MsgId:16, TopicId:16>>,
    ?LOG("send_subscribe_msg_predefined_topic TopicId=~p, MsgId=~p", [TopicId, MsgId]),
    ok = gen_udp:send(Socket, ?HOST, ?PORT, SubscribePacket).

send_subscribe_msg_short_topic(Socket, QoS, Topic, MsgId) ->
    Length = 7,
    MsgType = ?SN_SUBSCRIBE,
    Dup = 0,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    TopicIdType = ?SN_SHORT_TOPIC,
    SubscribePacket = <<Length:8, MsgType:8, Dup:1, QoS:2, Retain:1, Will:1,
        CleanSession:1, TopicIdType:2, MsgId:16, Topic/binary>>,
    ?LOG("send_subscribe_msg_short_topic Topic=~p, MsgId=~p", [Topic, MsgId]),
    ok = gen_udp:send(Socket, ?HOST, ?PORT, SubscribePacket).

send_subscribe_msg_reserved_topic(Socket, QoS, TopicId, MsgId) ->
    Length = 7,
    MsgType = ?SN_SUBSCRIBE,
    Dup = 0,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    TopicIdType = ?SN_RESERVED_TOPIC,
    SubscribePacket = <<Length:8, MsgType:8, Dup:1, QoS:2, Retain:1, Will:1,
        CleanSession:1, TopicIdType:2, MsgId:16, TopicId:16>>,
    ?LOG("send_subscribe_msg_reserved_topic TopicId=~p, MsgId=~p", [TopicId, MsgId]),
    ok = gen_udp:send(Socket, ?HOST, ?PORT, SubscribePacket).

send_unsubscribe_msg_predefined_topic(Socket, TopicId, MsgId) ->
    Length = 7,
    MsgType = ?SN_UNSUBSCRIBE,
    Dup = 0,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    TopicIdType = ?SN_PREDEFINED_TOPIC,
    UnSubscribePacket = <<Length:8, MsgType:8, Dup:1, 0:2, Retain:1, Will:1,
            CleanSession:1, TopicIdType:2, MsgId:16, TopicId:16>>,
    ?LOG("send_unsubscribe_msg_predefined_topic TopicId=~p, MsgId=~p", [TopicId, MsgId]),
    ok = gen_udp:send(Socket, ?HOST, ?PORT, UnSubscribePacket).

send_unsubscribe_msg_normal_topic(Socket, TopicName, MsgId) ->
    MsgType = ?SN_UNSUBSCRIBE,
    Dup = 0,
    QoS = 0,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    TopicIdType = ?SN_NORMAL_TOPIC,
    Length = 5 + byte_size(TopicName),
    UnSubscribePacket = <<Length:8, MsgType:8, Dup:1, QoS:2, Retain:1, Will:1,
        CleanSession:1, TopicIdType:2, MsgId:16, TopicName/binary>>,
    ?LOG("send_unsubscribe_msg_normal_topic TopicName=~p, MsgId=~p", [TopicName, MsgId]),
    ok = gen_udp:send(Socket, ?HOST, ?PORT, UnSubscribePacket).

send_unsubscribe_msg_short_topic(Socket, TopicId, MsgId) ->
    Length = 7,
    MsgType = ?SN_UNSUBSCRIBE,
    Dup = 0,
    Retain = 0,
    Will = 0,
    CleanSession = 0,
    TopicIdType = ?SN_SHORT_TOPIC,
    UnSubscribePacket = <<Length:8, MsgType:8, Dup:1, ?QOS_0:2, Retain:1, Will:1,
        CleanSession:1, TopicIdType:2, MsgId:16, TopicId/binary>>,
    ?LOG("send_unsubscribe_msg_short_topic TopicId=~p, MsgId=~p", [TopicId, MsgId]),
    ok = gen_udp:send(Socket, ?HOST, ?PORT, UnSubscribePacket).

send_pingreq_msg(Socket, ClientId)->
    Length = 2,
    MsgType = ?SN_PINGREQ,
    PingReqPacket = case ClientId of
                        undefined ->
                            <<Length:8, MsgType:8>>;
                        Other ->
                            Size = byte_size(Other)+2,
                            <<Size:8, MsgType:8, Other/binary>>
                    end,
    ?LOG("send_pingreq_msg ClientId=~p", [ClientId]),
    ok = gen_udp:send(Socket, ?HOST, ?PORT, PingReqPacket).

send_disconnect_msg(Socket, Duration) ->
    Length = 2, Length2 = 4,
    MsgType = ?SN_DISCONNECT,
    DisConnectPacket = case Duration of
                           undefined -> <<Length:8, MsgType:8>>;
                           Other     -> <<Length2:8, MsgType:8, Other:16>>
                       end,
    ?LOG("send_disconnect_msg Duration=~p", [Duration]),
    ok = gen_udp:send(Socket, ?HOST, ?PORT, DisConnectPacket).

mid(Id) -> Id.
tid(Id) -> Id.

receive_response(Socket) ->
    receive
        {udp, Socket, _, _, Bin} ->
            ?LOG("receive_response Bin=~p~n", [Bin]),
            Bin;
        {mqttc, From, Data2} ->
            ?LOG("receive_response() ignore mqttc From=~p, Data2=~p~n", [From, Data2]),
            receive_response(Socket);
        Other ->
            {unexpected_udp_data, Other},
            receive_response(Socket)
    after 2000 ->
        udp_receive_timeout
    end.

receive_emqttc_response() ->
    receive
        {mqttc, _From, Data2} ->
            Data2;
        {publish, Topic, Payload} ->
            {publish, Topic, Payload};
        Other -> {unexpected_emqttc_data, Other}
    after 2000 ->
        emqttc_receive_timeout
    end.

check_dispatched_message(Dup, QoS, Retain, TopicIdType, TopicId, Payload, Socket) ->
    PubMsg = receive_response(Socket),
    Length = 7 + byte_size(Payload),
    ?LOG("check_dispatched_message ~p~n", [PubMsg]),
    ?LOG("expected ~p xx ~p~n", [<<Length, ?SN_PUBLISH, Dup:1, QoS:2, Retain:1, ?FNU:2, TopicIdType:2, TopicId:16>>, Payload]),
    <<Length, ?SN_PUBLISH, Dup:1, QoS:2, Retain:1, ?FNU:2, TopicIdType:2, TopicId:16, MsgId:16, Payload/binary>> = PubMsg,
    case QoS of
        0 -> ok;
        1 -> send_puback_msg(Socket, TopicId, MsgId);
        2 -> send_pubrel_msg(Socket, MsgId),
            ?assertEqual(<<4, ?SN_PUBCOMP, MsgId:16>>, receive_response(Socket))
    end,
    ok.

get_udp_broadcast_address() ->
    "255.255.255.255".

check_publish_msg_on_udp({Dup, QoS, Retain, WillBit, CleanSession, TopicType, TopicId, Payload}, UdpData) ->
    <<HeaderUdp:5/binary, MsgId:16, PayloadIn/binary>> = UdpData,
    Size9 = byte_size(Payload) + 7,
    Eexp = <<Size9:8, ?SN_PUBLISH, Dup:1, QoS:2, Retain:1, WillBit:1, CleanSession:1, TopicType:2, TopicId:16>>,
    ?assertEqual(Eexp, HeaderUdp),     % mqtt-sn header should be same
    ?assertEqual(Payload, PayloadIn),  % payload should be same
    MsgId.

check_register_msg_on_udp(TopicName, UdpData) ->
    <<HeaderUdp:2/binary, TopicId:16, MsgId:16, PayloadIn/binary>> = UdpData,
    Size = byte_size(TopicName) + 6,
    ?assertEqual(<<Size:8, ?SN_REGISTER>>, HeaderUdp),
    ?assertEqual(TopicName, PayloadIn),
    {TopicId, MsgId}.

check_regack_msg_on_udp(MsgId, UdpData) ->
    <<7, ?SN_REGACK, TopicId:16, MsgId:16, 0:8>> = UdpData,
    TopicId.

set_special_configs(emqx) ->
    application:set_env(emqx, plugins_loaded_file,
                        emqx_ct_helpers:deps_path(emqx, "test/emqx_SUITE_data/loaded_plugins"));
set_special_configs(emqx_sn) ->
    application:set_env(emqx_sn, enable_qos3, ?ENABLE_QOS3),
    application:set_env(emqx_sn, enable_stats, true),
    application:set_env(emqx_sn, username, <<"user1">>),
    application:set_env(emqx_sn, password, <<"pw123">>),
    application:set_env(emqx_sn, predefined,
                        [{?PREDEF_TOPIC_ID1, ?PREDEF_TOPIC_NAME1},
                         {?PREDEF_TOPIC_ID2, ?PREDEF_TOPIC_NAME2}]);
set_special_configs(_App) ->
    ok.
