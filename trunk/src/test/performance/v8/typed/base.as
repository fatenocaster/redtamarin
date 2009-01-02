// Copyright 2008 the V8 project authors. All rights reserved.
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above
//       copyright notice, this list of conditions and the following
//       disclaimer in the documentation and/or other materials provided
//       with the distribution.
//     * Neither the name of Google Inc. nor the names of its
//       contributors may be used to endorse or promote products derived
//       from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


// Simple framework for running the benchmark suites and
// computing a score based on the timing measurements.


// A benchmark has a name (string) and a function that will be run to
// do the performance measurement.
class Benchmark {
    public var name:String;
    public var run:Function;
    public function Benchmark(name:String, run:Function) {
        this.name = name;
        this.run = run;
    }
}


// Benchmark results hold the benchmark and the measured time used to
// run the benchmark. The benchmark score is computed later once a
// full benchmark suite has run to completion.
class BenchmarkResult {
    private var benchmark:Benchmark;
    private var time:Number;
    public function BenchmarkResult(benchmark:Benchmark, time:Number):void {
        this.benchmark = benchmark;
        this.time = time;
    }

    // Automatically convert results to numbers. Used by the geometric
    // mean computation.
    public function valueOf() {
      return this.time;
    }
}





// Suites of benchmarks consist of a name and the set of benchmarks in
// addition to the reference timing that the final score will be based
// on. This way, all scores are relative to a reference run and higher
// scores implies better performance.
class BenchmarkSuite {

    // Keep track of all declared benchmark suites.
    static var suites:Array = [];
    
    // Scores are not comparable across versions. Bump the version if
    // you're making changes that will affect that scores, e.g. if you add
    // a new benchmark or change an existing one.
    public var version:String = '1';
    private var name:String;
    private var reference:Number;
    private var benchmarks:Array;
    private var results:Array;
    private var runner;
    static private var scores:Array;
    
    public function BenchmarkSuite(name:String, reference:Number, benchmarks:Array):void {
        this.name = name;
        this.reference = reference;
        this.benchmarks = benchmarks;
        BenchmarkSuite.suites.push(this);
    }
    
    // Runs all registered benchmark suites and optionally yields between
    // each individual benchmark to avoid running for too long in the
    // context of browsers. Once done, the final score is reported to the
    // runner.
    public static function RunSuites(runner):void {
      var continuation = null;
      var suites = BenchmarkSuite.suites;
      var length = suites.length;
      BenchmarkSuite.scores = [];
      var index = 0;
      function RunStep() {
        while (continuation || index < length) {
          if (continuation) {
            continuation = continuation();
          } else {
            var suite = suites[index++];
            if (runner.NotifyStart) runner.NotifyStart(suite.name);
            continuation = suite.RunStep(runner);
          }
          /* cpeyer - commented out for as tests as we never run in browser
          if (continuation && typeof window != 'undefined' && window.setTimeout) {
            window.setTimeout(RunStep, 100);
            return;
          }
          */
        }
        if (runner.NotifyScore) {
          var score = BenchmarkSuite.GeometricMean(BenchmarkSuite.scores);
          runner.NotifyScore(Math.round(100 * score));
        }
      }
      RunStep();
    }

    // Counts the total number of registered benchmarks. Useful for
    // showing progress as a percentage.
    public function CountBenchmarks() {
        var result:Number = 0;
        for (var i:int = 0; i < suites.length; i++) {
            result += suites[i].benchmarks.length;
        }
        return result;
    }
    
    
    // Computes the geometric mean of a set of numbers.
    public static function GeometricMean (numbers:Array):Number {
        var log:Number = 0;
        for (var i:int = 0; i < numbers.length; i++) {
            log += Math.log(numbers[i]);
        }
        return Math.pow(Math.E, log / numbers.length);
    }
    
    
    // Notifies the runner that we're done running a single benchmark in
    // the benchmark suite. This can be useful to report progress.
    public function NotifyStep(result:*):void {
      this.results.push(result);
      if (this.runner.NotifyStep) this.runner.NotifyStep(result.benchmark.name);
    }
    
    
    // Notifies the runner that we're done with running a suite and that
    // we have a result which can be reported to the user if needed.
    public function NotifyResult():void {
      var mean:Number = BenchmarkSuite.GeometricMean(this.results);
      var score:Number = this.reference / mean;
      BenchmarkSuite.scores.push(score);
      if (this.runner.NotifyResult) {
        this.runner.NotifyResult(this.name, Math.round(100 * score));
      }
    }
    
    
    // Runs a single benchmark for at least a second and computes the
    // average time it takes to run a single iteration.
    public function RunSingle(benchmark:Benchmark):void {
      var elapsed = 0;
      var start = new Date();
      for (var n = 0; elapsed < 1000; n++) {
        benchmark.run();
        elapsed = Number(new Date()) - start;
      }
      var usec = (elapsed * 1000) / n;
      this.NotifyStep(new BenchmarkResult(benchmark, usec));
    }
    
    
    // This function starts running a suite, but stops between each
    // individual benchmark in the suite and returns a continuation
    // function which can be invoked to run the next benchmark. Once the
    // last benchmark has been executed, null is returned.
    public function RunStep(runner):Function {
      this.results = [];
      this.runner = runner;
      var length = this.benchmarks.length;
      var index = 0;
      var suite = this;
      function RunNext() {
        if (index < length) {
          suite.RunSingle(suite.benchmarks[index++]);
          return RunNext;
        }
        suite.NotifyResult();
        return null;
      }
      return RunNext();
    }

} // class BenchmarkSuite

function PrintResult(name, result) {
  // print(name + ': ' + result);
  print('name '+name);
  print('metric v8 ' + result);
}

function PrintScore(score) {
  print('----');
  print('Score: ' + score);
}