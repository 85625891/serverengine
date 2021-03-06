#
# ServerEngine
#
# Copyright (C) 2012-2013 Sadayuki Furuhashi
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#
module ServerEngine

  class Server
    include ConfigLoader

    def initialize(worker_module, load_config_proc={}, &block)
      @worker_module = worker_module

      @stop = false

      super(load_config_proc, &block)
    end

    def before_run
    end

    def after_run
    end

    def stop(stop_graceful)
      @stop = true
      nil
    end

    def after_start
    end

    def restart(stop_graceful)
      reload_config
      @logger.reopen! if @logger
      nil
    end

    def reload
      reload_config
      @logger.reopen! if @logger
      nil
    end

    def install_signal_handlers
      s = self
      SignalThread.new do |st|
        st.trap(Daemon::Signals::GRACEFUL_STOP) { s.stop(true) }
        st.trap(Daemon::Signals::IMMEDIATE_STOP) { s.stop(false) }
        st.trap(Daemon::Signals::GRACEFUL_RESTART) { s.restart(true) }
        st.trap(Daemon::Signals::IMMEDIATE_RESTART) { s.restart(false) }
        st.trap(Daemon::Signals::RELOAD) { s.reload }
        st.trap(Daemon::Signals::DETACH) { s.stop(true) }
        st.trap(Daemon::Signals::DUMP) { Sigdump.dump }
      end
    end

    def main
      create_logger unless @logger

      before_run

      begin
        run
      ensure
        after_run
      end
    end

    module WorkerInitializer
      def initialize
      end
    end

    private

    def create_worker(wid)
      w = Worker.new(self, wid)
      w.extend(WorkerInitializer)
      w.extend(@worker_module)
      w.instance_eval { initialize }
      w
    end
  end

end
