# S3 Bench
This tool offers the ability to run very basic throughput benchmarking against
an S3-compatible endpoint. It does a series of put operations followed by a
series of get operations and displays the corresponding statistics. The tool
uses the AWS Go SDK.

## Requirements
This has been tested on various *nix platforms (mainly linux), as well as MacOS.  It has not been tested on windows.

## Installation

### Docker

```docker pull andypern/s3bench```

### Static Binary
You can always grab the latest statically compiled binary (for linux x86_64) from <https://github.com/andypern/s3bench/raw/master/s3bench>

### Building from Source

Run the following command to build the binary.

```
go get github.com/andypern/s3bench
```
The binary will be placed under $GOPATH/bin/s3bench.

manual compile:

```
go build -ldflags "-linkmode external -extldflags -static"
```


If you lack a proper go environment to build on, use Docker. Check the `Dockerfile` in this repo to determine the build dependancies.

## Usage
The s3bench command is self-describing. In order to see all the available options
just run s3bench -help.

### IO profiles (-operations)

These are the  `-operations` which are supported:

* write : this will measure object PUTs (both regular and multipart).  
* read : this will measure object GETs (both regular and multipart).  Note that you MUST run this against a bucket/objNameprefix which you previously ran a `-operations write` or `-operations both` test.
* both : this will first run writes, then reads.
* ranges : this is a special case just for 'ranged reads'.  It will perform random partial reads against existing objects (which you must create beforehand using `-operations write`).  It requires some supplemental flags:
    * `-rangeSize` : defaults to 1024 bytes (1KiB).  This is the size of each read request.
    * `-numRequests` : defaults to 10240.  This is the total number of requests that the test will execute, regardless of the number of threads (`-numClients`).
    * `-numSamples` : defaults to 200.  The number of files to distribute (randomly) the ranged read requests across.  This can be as few as 1.  Note that you will need to ensure that at least this many objects already exist with the correct bucket & objectNamePrefix , by using `-operations write` in a previous run.

### Example input
The following will run a benchmark from 2 concurrent sessions, which in
aggregate will put a total of 10 unique new objects. Each object will be
exactly 1024 bytes. The objects will be placed in a bucket named loadgen.
The S3 endpoint will be ran against http://endpoint1:80 and
http://endpoint2:80. Object name will be prefixed with loadgen.

```
./s3bench -accessKey=KEY -accessSecret=SECRET -bucket=loadgen -endpoint=http://endpoint1:80,http://endpoint2:80 -numClients=2 -numSamples=10 -objectNamePrefix=loadgen -objectSize=1024
```


### Running on multiple hosts

While `s3bench` does not have a facility built-in to perform multi-host parallelization, one can use `clush` ( < https://clustershell.readthedocs.io/en/latest/ > ) , pssh, pdsh, or similar tools to run simultaneously on multiple clients.  Here are a couple simple examples, note the use of quotes and escaping of `$` variables in some cases

```
clush -g cb2 "/home/vastdata/s3bench \
-accessKey $AWS_ACCESS_KEY_ID \
-accessSecret $AWS_SECRET_ACCESS_KEY \
-bucket \$(hostname)-benchmark -endpoint \
$(echo http://172.200.3.{1..8},|sed "s/ //g"|sed "s/,$//") \
-numClients 80 \
-numSamples 1000 \
-objectSize \$((100*1024*1024)) \
-operations both"


```




### Note on regions & endpoints
By default, the region used will be `vast-west` , a fictitious region which
is suitable for using with the VAST systems.  However, you can elect to
use this tool with Amazon S3, in which case you will need to specify the proper region.

It is also important when using Amazon S3 that you specify the proper endpoint, which
will generally be `http://s3-regionName.amazonaws.com:80`. EG: if the bucket which you are
testing is in Oregon, you would specify:

```
-endpoint http://s3-us-west-2.amazonaws.com:80 -region us-west-2
```

For more information on this, please refer to [AmazonS3 documentation.](https://aws.amazon.com/documentation/s3/)


### Note on multipart
Specifying `-multipart` will only impact writes, not reads (so far).  The current multipart implementation does NOT use the `s3manager` package, rather it is creating parts individually and sending them in parallel per object. Also:
* The program will generate `-partsize` bytes of random data to use. Each part will be 100% identical (except for the last part, which is smaller).  This will be changed to be more random later.
* specifying `-numClients` starts up XX sessions, which translates to maximum concurrent object-uploads: however each object-upload will leverage `-multiUploaders` , so the effect is multiplicative.  Use with care.  Put another way:
   * `-numclients 10` && `-multiUploaders 10` means there will be 100 concurrent threads uploading.
* you can specify `-partSize` in bytes.  Note that the minimum supported by the SDK is 5MiB.





### Example output
The output will consist of details for every request being made as well as the
current average throughput. At the end of the run summaries of the put and get
operations will be displayed.

```
Test parameters
endpoint(s):      [http://172.200.3.1 http://172.200.3.2 http://172.200.3.3 http://172.200.3.4 http://172.200.3.5 http://172.200.3.6 http://172.200.3.7 http://172.200.3.8]
bucket:           selab-cb9-c3
objectNamePrefix: selab-cb9-c3_loadgen_test/
objectSize:       100.0000 MB
numClients:       80
numSamples:       1000
batchSize:       1000
Total size of data set : 97.6562 GB
verbose:       false


2021/04/27 23:05:42 creating bucket if required
Generating 209715200 bytes in-memory sample data... Done (1.554669803s)

Running Write test...
Running Read test...
Results Summary for Write Operation(s)
Total Transferred: 100000.000 MB
Total Throughput:  4248.42 MB/s
Ops/sec:  42.48 ops/s
Total Duration:    23.538 s
Number of Errors:  0
------------------------------------
Write times Max:       2.9262 s
Write times 99th %ile: 2.7422 s
Write times 90th %ile: 2.5406 s
Write times 75th %ile: 2.2856 s
Write times 50th %ile: 1.8921 s
Write times 25th %ile: 0.9137 s
Write times Min:       0.3677 s


Results Summary for Read Operation(s)
Total Transferred: 100000.000 MB
Total Throughput:  10554.29 MB/s
Ops/sec:  105.54 ops/s
Total Duration:    9.475 s
Number of Errors:  0
------------------------------------
Read times Max:       1.8492 s
Read times 99th %ile: 1.5404 s
Read times 90th %ile: 1.0935 s
Read times 75th %ile: 0.9415 s
Read times 50th %ile: 0.7914 s
Read times 25th %ile: 0.4691 s
Read times Min:       0.1365 s



Cleaning up 1000 objects...
Successfully deleted 1000/1000 objects in 3.618969207s
deleted bucket selab-cb9-c3

```
