# Copyright 2017 The Wallaroo Authors.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
#  implied. See the License for the specific language governing
#  permissions and limitations under the License.


# import requisite components for integration test
from integration import (add_runner,
                         ex_validate,
                         get_port_values,
                         Metrics,
                         MetricsParser,
                         Reader,
                         Runner,
                         RunnerReadyChecker,
                         Sender,
                         sequence_generator,
                         setup_resilience_path,
                         Sink,
                         SinkAwaitValue,
                         start_runners,
                         TimeoutError)
import os
import re
import struct
import time


def test_autoscale_grow_pony():
    command = 'sequence_window'
    _test_autoscale_grow(command)


#def test_autoscale_grow_machida():
#    command = 'machida --application-module sequence_window'
#    _test_autoscale_grow(command)


def _test_autoscale_grow(command):
    host = '127.0.0.1'
    sources = 1
    workers = 1
    res_dir = '/tmp/res-data'
    expect = 2000
    last_value_0 = '[{}]'.format(','.join((str(expect-v) for v in range(6,-2,-2))))
    last_value_1 = '[{}]'.format(','.join((str(expect-1-v) for v in range(6,-2,-2))))

    await_values = (struct.pack('>I', len(last_value_0)) + last_value_0,
                    struct.pack('>I', len(last_value_1)) + last_value_1)


    setup_resilience_path(res_dir)

    runners = []
    try:
        # Create sink, metrics, reader, sender
        sink = Sink(host)
        metrics = Metrics(host)
        reader = Reader(sequence_generator(expect))

        # Start sink and metrics, and get their connection info
        sink.start()
        sink_host, sink_port = sink.get_connection_info()
        outputs = '{}:{}'.format(sink_host, sink_port)

        metrics.start()
        metrics_host, metrics_port = metrics.get_connection_info()
        time.sleep(0.05)

        input_ports, control_port, external_port, data_port = (
            get_port_values(host, sources))
        inputs = ','.join(['{}:{}'.format(host, p) for p in
                           input_ports])

        start_runners(runners, command, host, inputs, outputs,
                      metrics_port, control_port, external_port, data_port,
                      res_dir, workers)

        # Wait for first runner (initializer) to report application ready
        runner_ready_checker = RunnerReadyChecker(runners, timeout=30)
        runner_ready_checker.start()
        runner_ready_checker.join()
        if runner_ready_checker.error:
            raise runner_ready_checker.error

        # start sender
        sender = Sender(host, input_ports[0], reader, batch_size=10,
                        interval=0.05)
        sender.start()
        time.sleep(4)

        # create a new worker and have it join
        add_runner(runners, command, host, inputs, outputs, metrics_port,
                   control_port, external_port, data_port, res_dir, workers)


        # wait until sender completes (~10 seconds)
        sender.join(30)
        if sender.error:
            raise sender.error
        if sender.is_alive():
            sender.stop()
            raise TimeoutError('Sender did not complete in the expected '
                               'period')

        # Use Sink value to determine when to stop runners and sink
        stopper = SinkAwaitValue(sink, await_values, 30)
        stopper.start()
        stopper.join()
        if stopper.error:
            raise stopper.error

        # stop application workers
        for r in runners:
            r.stop()

        # Stop sink
        sink.stop()
        print 'sink.data size: ', len(sink.data)

        # Stop metrics
        metrics.stop()

        # parse metrics data and validate worker has shifted from 1 to 2
        # workers
        mp = MetricsParser()
        mp.load_string_list(metrics.data)
        mp.parse()
        # Now confirm that there are computations in worker1's metrics
        app_key = mp.data.keys()[0]  # 'metrics:Sequence Window Printer'
        worker_metrics = mp.data[app_key].get('worker1', None)
        assert(worker_metrics is not None)  # worker metrics aren't empty
        # Verify there is at least one entry for a computation with a nonzero
        # total value
        filtered = filter(lambda v: (v[0] == 'metrics'
                                     and
                                     v[1]['metrics_category'] == 'computation'
                                     and
                                     v[1]['total'] > 0),
                          worker_metrics)
        assert(len(filtered) > 0)

        # Use validator to validate the data in at-least-once mode
        # save sink data to a file
        out_file = os.path.join(res_dir, 'received.txt')
        sink.save(out_file, mode='giles')


        # Validate captured output
        cmd_validate = ('validator -i {out_file} -e {expect} -a'
                        .format(out_file = out_file,
                                expect = expect))
        success, stdout, retcode, cmd = ex_validate(cmd_validate)
        try:
            assert(success)
        except AssertionError:
            print runners[-1].get_output()[0]
            print '---'
            print runners[-2].get_output()[0]
            print '---'
            raise AssertionError('Validation failed with the following '
                                 'error:\n{}'.format(stdout))

        # Validate worker actually joined
        patterns_i = [r'Migrating partitions to worker2',
                      r'--All new workers have acked migration batch complete',
                      r'~~~Resuming message processing.~~~']
        patterns_w = [r'***Successfully joined cluster!***',
                      r'~~~Resuming message processing.~~~']
        stdout_i, stderr_i = runners[0].get_output()
        stdout_w, stderr_w = runners[1].get_output()
        for p in patterns_i:
            try:
                assert(re.search(p, stdout_i) is not None)
            except AssertionError:
                raise AssertionError('Grow to fit messages missing on '
                                     'initializer. Initializer output '
                                     'included below.\nSTDOUT\n---\n%s\n---\n'
                                     'STDERR\n---\n%s' % (stdout_i, stderr_i))
        for p in patterns_w:
            try:
                assert(re.search(p, stdout_w) is not None)
            except AssertionError:
                raise AssertionError('Grow to fit messages missing on '
                                     'worker. Worker output '
                                     'included below.\nSTDOUT\n---\n%s\n---\n'
                                     'STDERR\n---\n%s' % (stdout_w, stderr_w))

    finally:
        for r in runners:
            r.stop()
