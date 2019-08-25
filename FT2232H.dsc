{
    "Channel Mode": "Use Channels 0~15 (Max 100MHz)",
    "Device": "DSLogic",
    "DeviceMode": 0,
    "Enable RLE Compress": 0,
    "Filter Targets": "None",
    "Horizontal trigger position": "0",
    "Max Height": "1X",
    "Operation Mode": "Buffer Mode",
    "Sample count": "20000000",
    "Sample rate": "100000000",
    "Stop Options": "Upload captured data",
    "Threshold Level": 1,
    "Trigger channel": "0",
    "Trigger hold off": "0",
    "Trigger margin": "8",
    "Trigger slope": "0",
    "Trigger source": "0",
    "Using Clock Negedge": 0,
    "Using External Clock": 0,
    "Version": 2,
    "channel": [
        {
            "colour": "#969696",
            "enabled": true,
            "index": 0,
            "name": "rxf_n",
            "strigger": 0,
            "type": 10000
        },
        {
            "colour": "#969696",
            "enabled": true,
            "index": 1,
            "name": "txe_n",
            "strigger": 0,
            "type": 10000
        },
        {
            "colour": "#969696",
            "enabled": true,
            "index": 2,
            "name": "rd_n",
            "strigger": 0,
            "type": 10000
        },
        {
            "colour": "#969696",
            "enabled": true,
            "index": 3,
            "name": "wr_n",
            "strigger": 0,
            "type": 10000
        },
        {
            "colour": "#969696",
            "enabled": true,
            "index": 8,
            "name": "D0",
            "strigger": 0,
            "type": 10000
        },
        {
            "colour": "#969696",
            "enabled": true,
            "index": 9,
            "name": "D1",
            "strigger": 0,
            "type": 10000
        },
        {
            "colour": "#969696",
            "enabled": true,
            "index": 10,
            "name": "D2",
            "strigger": 0,
            "type": 10000
        },
        {
            "colour": "#969696",
            "enabled": true,
            "index": 11,
            "name": "D3",
            "strigger": 0,
            "type": 10000
        },
        {
            "colour": "#969696",
            "enabled": true,
            "index": 12,
            "name": "D4",
            "strigger": 0,
            "type": 10000
        },
        {
            "colour": "#969696",
            "enabled": true,
            "index": 13,
            "name": "D5",
            "strigger": 0,
            "type": 10000
        },
        {
            "colour": "#969696",
            "enabled": true,
            "index": 14,
            "name": "D6",
            "strigger": 0,
            "type": 10000
        },
        {
            "colour": "#969696",
            "enabled": true,
            "index": 15,
            "name": "D7",
            "strigger": 0,
            "type": 10000
        }
    ],
    "decoder": [
        {
            "channel": [
                {
                    "d0": 8
                },
                {
                    "d1": 9
                },
                {
                    "clk": 2
                },
                {
                    "d2": 10
                },
                {
                    "d7": 15
                },
                {
                    "d6": 14
                },
                {
                    "d3": 11
                },
                {
                    "d5": 13
                },
                {
                    "d4": 12
                }
            ],
            "id": "parallel",
            "options": {
                "clock_edge": "rising",
                "endianness": "big",
                "wordsize": 0
            },
            "show": {
                "Parallel": true,
                "parallel": true
            },
            "stacked decoders": [
            ]
        },
        {
            "channel": [
                {
                    "d0": 8
                },
                {
                    "d1": 9
                },
                {
                    "clk": 3
                },
                {
                    "d2": 10
                },
                {
                    "d7": 15
                },
                {
                    "d6": 14
                },
                {
                    "d3": 11
                },
                {
                    "d5": 13
                },
                {
                    "d4": 12
                }
            ],
            "id": "parallel",
            "options": {
                "clock_edge": "rising",
                "endianness": "big",
                "wordsize": 1
            },
            "show": {
                "Parallel": true,
                "parallel": true
            },
            "stacked decoders": [
            ]
        }
    ],
    "trigger": {
        "advTriggerMode": true,
        "serialTriggerBits": 0,
        "serialTriggerChannel": 0,
        "serialTriggerClock": "X X X X X X X X X X X X X X X X",
        "serialTriggerData": "X X X X X X X X X X X X X X X X",
        "serialTriggerStart": "X X X X X X X X X X X X X X X X",
        "serialTriggerStop": "X X X X X X X X X X X X X X X X",
        "stageTriggerContiguous0": false,
        "stageTriggerContiguous1": false,
        "stageTriggerContiguous10": false,
        "stageTriggerContiguous11": false,
        "stageTriggerContiguous12": false,
        "stageTriggerContiguous13": false,
        "stageTriggerContiguous14": false,
        "stageTriggerContiguous15": false,
        "stageTriggerContiguous2": false,
        "stageTriggerContiguous3": false,
        "stageTriggerContiguous4": false,
        "stageTriggerContiguous5": false,
        "stageTriggerContiguous6": false,
        "stageTriggerContiguous7": false,
        "stageTriggerContiguous8": false,
        "stageTriggerContiguous9": false,
        "stageTriggerCount0": 1,
        "stageTriggerCount1": 1,
        "stageTriggerCount10": 1,
        "stageTriggerCount11": 1,
        "stageTriggerCount12": 1,
        "stageTriggerCount13": 1,
        "stageTriggerCount14": 1,
        "stageTriggerCount15": 1,
        "stageTriggerCount2": 1,
        "stageTriggerCount3": 1,
        "stageTriggerCount4": 1,
        "stageTriggerCount5": 1,
        "stageTriggerCount6": 1,
        "stageTriggerCount7": 1,
        "stageTriggerCount8": 1,
        "stageTriggerCount9": 1,
        "stageTriggerInv00": 0,
        "stageTriggerInv01": 0,
        "stageTriggerInv010": 0,
        "stageTriggerInv011": 0,
        "stageTriggerInv012": 0,
        "stageTriggerInv013": 0,
        "stageTriggerInv014": 0,
        "stageTriggerInv015": 0,
        "stageTriggerInv02": 0,
        "stageTriggerInv03": 0,
        "stageTriggerInv04": 0,
        "stageTriggerInv05": 0,
        "stageTriggerInv06": 0,
        "stageTriggerInv07": 0,
        "stageTriggerInv08": 0,
        "stageTriggerInv09": 0,
        "stageTriggerInv10": 0,
        "stageTriggerInv11": 0,
        "stageTriggerInv110": 0,
        "stageTriggerInv111": 0,
        "stageTriggerInv112": 0,
        "stageTriggerInv113": 0,
        "stageTriggerInv114": 0,
        "stageTriggerInv115": 0,
        "stageTriggerInv12": 0,
        "stageTriggerInv13": 0,
        "stageTriggerInv14": 0,
        "stageTriggerInv15": 0,
        "stageTriggerInv16": 0,
        "stageTriggerInv17": 0,
        "stageTriggerInv18": 0,
        "stageTriggerInv19": 0,
        "stageTriggerLogic0": 0,
        "stageTriggerLogic1": 1,
        "stageTriggerLogic10": 1,
        "stageTriggerLogic11": 1,
        "stageTriggerLogic12": 1,
        "stageTriggerLogic13": 1,
        "stageTriggerLogic14": 1,
        "stageTriggerLogic15": 1,
        "stageTriggerLogic2": 1,
        "stageTriggerLogic3": 1,
        "stageTriggerLogic4": 1,
        "stageTriggerLogic5": 1,
        "stageTriggerLogic6": 1,
        "stageTriggerLogic7": 1,
        "stageTriggerLogic8": 1,
        "stageTriggerLogic9": 1,
        "stageTriggerValue00": "X X X X X X X X X X X X X F X X",
        "stageTriggerValue01": "X X X X X X X X X X X X X X X X",
        "stageTriggerValue010": "X X X X X X X X X X X X X X X X",
        "stageTriggerValue011": "X X X X X X X X X X X X X X X X",
        "stageTriggerValue012": "X X X X X X X X X X X X X X X X",
        "stageTriggerValue013": "X X X X X X X X X X X X X X X X",
        "stageTriggerValue014": "X X X X X X X X X X X X X X X X",
        "stageTriggerValue015": "X X X X X X X X X X X X X X X X",
        "stageTriggerValue02": "X X X X X X X X X X X X X X X X",
        "stageTriggerValue03": "X X X X X X X X X X X X X X X X",
        "stageTriggerValue04": "X X X X X X X X X X X X X X X X",
        "stageTriggerValue05": "X X X X X X X X X X X X X X X X",
        "stageTriggerValue06": "X X X X X X X X X X X X X X X X",
        "stageTriggerValue07": "X X X X X X X X X X X X X X X X",
        "stageTriggerValue08": "X X X X X X X X X X X X X X X X",
        "stageTriggerValue09": "X X X X X X X X X X X X X X X X",
        "stageTriggerValue10": "X X X X X X X X X X X X F X X X",
        "stageTriggerValue11": "X X X X X X X X X X X X X X X X",
        "stageTriggerValue110": "X X X X X X X X X X X X X X X X",
        "stageTriggerValue111": "X X X X X X X X X X X X X X X X",
        "stageTriggerValue112": "X X X X X X X X X X X X X X X X",
        "stageTriggerValue113": "X X X X X X X X X X X X X X X X",
        "stageTriggerValue114": "X X X X X X X X X X X X X X X X",
        "stageTriggerValue115": "X X X X X X X X X X X X X X X X",
        "stageTriggerValue12": "X X X X X X X X X X X X X X X X",
        "stageTriggerValue13": "X X X X X X X X X X X X X X X X",
        "stageTriggerValue14": "X X X X X X X X X X X X X X X X",
        "stageTriggerValue15": "X X X X X X X X X X X X X X X X",
        "stageTriggerValue16": "X X X X X X X X X X X X X X X X",
        "stageTriggerValue17": "X X X X X X X X X X X X X X X X",
        "stageTriggerValue18": "X X X X X X X X X X X X X X X X",
        "stageTriggerValue19": "X X X X X X X X X X X X X X X X",
        "triggerPos": 1,
        "triggerStages": 0,
        "triggerTab": 0
    }
}
