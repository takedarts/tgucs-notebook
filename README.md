# Dockerfile of TGUCS-Notebook
Dockerfile of Jupyter Notebook for Department of Information Science, Tohoku Gakuin University

## これは何？
東北学院大学教養学部情報科学科の情報処理演習用として作成したDockerfileです。
作成されたDockerイメージをロードするとJupyterNotebookが起動し、Webブラウザからpythonやprocessingなどのプログラミング環境を利用できます。

## 使い方
DockerHubにDockerイメージを登録してありますので、これをダウンロードして実行します。

```
% docker pull takedarts/tgucs-notebook:latest
latest: Pulling from takedarts/tgucs-notebook
...
Status: Downloaded newer image for takedarts/tgucs-notebook:latest
docker.io/takedarts/tgucs-notebook:latest

% docker run --rm -it -u 0 -p 8888:8888 takedarts/tgucs-notebook
...
http://cdee29d2143d:8888/?token=[token]
 or http://127.0.0.1:8888/?token=[token]
```

実行時に表示されたURL(`http://127.0.0.1:8888/?token=[token]`)をWebブラウザで開くとJupyterNotebookを利用できます。

## 利用可能なkernel
- python3 (xpython3)
- bash
- [processing](https://github.com/Calysto/calysto_processing)
- [maxima](https://github.com/robert-dodier/maxima-jupyter)

## 追記
Ubuntu-20.04の環境下で実行すると以下のエラーが発生します（これは、ベースとなっている`ubuntu:22.04`に由来するエラーです）。
```
Fail to get yarn configuration. /opt/conda/bin/node[45]: ../../src/node_platform.cc:61:std::unique_ptr<long unsigned int> node::WorkerThreadsTaskRunner::DelayedTaskScheduler::Start(): Assertion `(0) == (uv_thread_create(t.get(), start_thread, this))' failed.
 1: 0x7fd776d313f9 node::Abort() [/opt/conda/bin/../lib/libnode.so.108]
...
```
実行時にオプション`--security-opt seccomp=unconfined`を追加することで上記のエラーを回避できます。
```
% docker run --rm -it --security-opt seccomp=unconfined -u 0 -p 8888:8888 takedarts/tgucs-notebook
```