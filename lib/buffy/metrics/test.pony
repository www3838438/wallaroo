use "ponytest"
use "buffy/messages"
use "sendence/bytes"
use "collections"
use "itertools"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)


  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestNodeReportsEncoder)
    test(_TestBoundaryReportsEncoder)
    test(_TestMonitoringHubEncoder)

class iso _TestNodeReportsEncoder is UnitTest
  fun name(): String => "buffy:NodeReportsEncoder"

  fun apply(h: TestHelper) ? =>
    let node_name = "Test"
    let report_map = Map[_StepId, Array[StepMetricsReport val]]

    report_map(1) = Array[StepMetricsReport val]
    report_map(1).push(StepMetricsReport(1232143143, 1354551314))
    report_map(1).push(StepMetricsReport(1232347892, 1354328734))
    report_map(1).push(StepMetricsReport(1242596283, 1123612344))
    report_map(1).push(StepMetricsReport(1298273467, 1354275829))
    report_map(1).push(StepMetricsReport(1223498726, 1313488791))

    report_map(2) = Array[StepMetricsReport val]
    report_map(2).push(StepMetricsReport(1232143112, 1354551313))
    report_map(2).push(StepMetricsReport(1232347867, 1354328748))
    report_map(2).push(StepMetricsReport(1242596287, 1123612390))
    report_map(2).push(StepMetricsReport(1298273412, 1354275808))
    report_map(2).push(StepMetricsReport(1223498723, 1313488789))

    let node_encoded = NodeMetricsEncoder(node_name, report_map)

    let node_decoded = ReportMsgDecoder(consume node_encoded)

    match node_decoded
    | let n: NodeMetricsSummary val =>
      h.assert_eq[String](n.node_name, "Test")
      h.assert_eq[U64](n.digests(0).reports(2).start_time, 1242596287)
    else
      h.fail("Wrong decoded message type")
    end

    true

class iso _TestBoundaryReportsEncoder is UnitTest
  fun name(): String => "buffy:BoundaryReportsEncoder"

  fun apply(h: TestHelper) ? =>
    let boundary_node_name = "BoundaryTest"
    let boundary_reports = Array[BoundaryMetricsReport val]

    boundary_reports.push(BoundaryMetricsReport(BoundaryTypes.source_sink(), 9143, 91354551, 1232143112))
    boundary_reports.push(BoundaryMetricsReport(BoundaryTypes.source_sink(), 9147, 91354328, 1354328748))
    boundary_reports.push(BoundaryMetricsReport(BoundaryTypes.source_sink(), 9196, 91123612, 1313488789))
    boundary_reports.push(BoundaryMetricsReport(BoundaryTypes.source_sink(), 9173, 91354275, 1313488789))
    boundary_reports.push(BoundaryMetricsReport(BoundaryTypes.source_sink(), 9198, 91313488, 1354275829))

    let boundary_encoded = BoundaryMetricsEncoder(boundary_node_name, boundary_reports)

    let boundary_decoded = ReportMsgDecoder(consume boundary_encoded)

    match boundary_decoded
    | let n: BoundaryMetricsSummary val =>
      h.assert_eq[String](n.node_name, "BoundaryTest")
      h.assert_eq[U64](n.reports(1).start_time, 91354328)
    else
      h.fail("Wrong decoded message type")
    end

    true

class iso _TestMonitoringHubEncoder is UnitTest
  fun name(): String => "buffy:SinkMetricsEncoder"

  fun apply(h: TestHelper)  =>
    let output = MetricsAccumulatorActor
    let handler: MetricsCollectionOutputHandler iso =
      recover iso MetricsStringAccumulator(MonitoringHubEncoder, output) end
    
    let bin_selector: F64Selector val = recover val Log10Selector end
    let mc: MetricsCollection = MetricsCollection(bin_selector, 1,
                                                  consume handler)
    
    let nms:NodeMetricsSummary iso = recover NodeMetricsSummary("node1") end
    let digest:StepMetricsDigest iso = recover StepMetricsDigest(999) end
    
    digest.add_report(StepMetricsReport(10010, 10550))
    digest.add_report(StepMetricsReport(10650, 12250))
    nms.add_digest(consume digest)
    
    let bms: BoundaryMetricsSummary iso = recover
      BoundaryMetricsSummary("node1") end
    bms.add_report(BoundaryMetricsReport(0, 10000, 10050, 10250))
    bms.add_report(BoundaryMetricsReport(0, 10001, 11150, 11600))
    bms.add_report(BoundaryMetricsReport(1, 10002, 15050, 15300))
    bms.add_report(BoundaryMetricsReport(1, 10003, 15400, 15500))

    let bms': BoundaryMetricsSummary val = consume bms
    let nms': NodeMetricsSummary val = consume nms
    // Process summaries for step, sink, and boundary
    mc.process_summary(nms')
    mc.process_summary(bms')

    // Process the collection with the handlers array
    mc.send_output()

    true

