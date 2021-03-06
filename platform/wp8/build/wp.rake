#------------------------------------------------------------------------
# (The MIT License)
# 
# Copyright (c) 2008-2011 Rhomobile, Inc.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
# 
# http://rhomobile.com
#------------------------------------------------------------------------

namespace "config" do
  task :set_wp8_platform do
    $current_platform = "wp" unless $current_platform
  end

  task :wp8 => [:set_wp8_platform, "config:common"] do
    $rubypath     = "res/build-tools/RhoRuby.exe"
    $zippath      = "res/build-tools/7za.exe"
    $wp7runner    = "res/build-tools/RhoAppRunnerWP8.exe"
    $wp7logserver = "res/build-tools/RhoLogserver.exe"
    $builddir     = $config["build"]["wp8path"] + "/build"
    $vcbindir     = $config["build"]["wp8path"] + "/bin"
    $appname      = $app_config["name"].nil? ? "Rhodes" : $app_config["name"] 
    $bindir       = $app_path + "/bin"
    $rhobundledir = $app_path + "/RhoBundle"
    $srcdir       = $bindir   + "/RhoBundle"
    $targetdir    = $bindir   + "/target/wp8"
    $tmpdir       = $bindir   +"/tmp"
    
    $msbuild      = $config["env"]["paths"]["msbuild"]
    $msbuild      = "msbuild" if $msbuild.nil?

    $sdk          = "Windows Phone 8 SDK"
    $sdk          = $app_config["wpsdk"] unless $app_config["wpsdk"].nil?

    $excludelib = ['**/builtinME.rb','**/ServeME.rb','**/dateME.rb','**/rationalME.rb']

    if !$app_config["wp"] || !$app_config["wp"]["productid"]
      puts "Add wp:productid to application build.yml"
      puts "productid is GUID in format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
      puts "for example:"
      puts "wp:"
      puts "  productid: 'fd55c4d0-51fa-012e-7844-3caec51bd50e'"

      exit 1
		end		
	end
end

def addRhobundleFilesToCacheFileCommon(cfgName)
  out_dir = $startdir + "/" + $vcbindir + "/rhodes/#{cfgName}/"

  doc = REXML::Document.new(File.open(out_dir + "XapCacheFile.xml"))
  chdir $srcdir

  Dir.glob(File.join("**", '*.*')).each do |f|
    doc.root[1,0] = REXML::Element.new "file lastWriteTime='" + File.mtime(f).strftime("%m/%d/%Y %I:%M:%S %p") + "' source='" + $srcdir.gsub("/", "\\") + "\\" + f.gsub("/", "\\") + "' archivePath='rho\\" + f.gsub("/", "\\") + "'" 
  end

  File.open(out_dir + "XapCacheFile.xml", "w") { |f| doc.write f, 2; f.close }

  chdir $startdir

  mkdir_p $config["build"]["wp8path"] + "/rhodes/obj/#{cfgName}" if not File.exists? $config["build"]["wp8path"] + "/rhodes/obj/#{cfgName}"
  cp out_dir + "XapCacheFile.xml", $config["build"]["wp8path"] + "/rhodes/obj/#{cfgName}"
end
 
namespace "build" do
  namespace "wp8" do

    task :extensions => "config:wp8" do
      $app_config["extensions"].each do |ext|
        $app_config["extpaths"].each do |p|
          extpath = File.join(p, ext, 'ext')
          next unless File.exists? File.join(extpath, "build.bat")

          ENV['RHO_PLATFORM'] = 'wp'
          ENV['PWD'] = $startdir
          ENV['RHO_ROOT'] = ENV['PWD']
          ENV['TARGET_TEMP_DIR'] = File.join(ENV['PWD'], "platform", "wp8", "bin", $sdk, "rhodes", "Release")
          ENV['TEMP_FILES_DIR'] = File.join(ENV['PWD'], "platform", "wp8", "bin", $sdk, "extensions", ext)
          ENV['MSBUILD'] = $msbuild
          ENV['SDK'] = $sdk
      
          puts Jake.run("build.bat", [], extpath)
          break
        end
      end
    end

    desc "Build WP8 rhobundle"
    task :rhobundle => ["config:wp8", "build:bundle:noxruby"] do
      #move public folder to root
      cp_r $srcdir + "/apps/public", $srcdir + "/public"
      rm_r $srcdir + "/apps/public"
    end

    # create file with map of bundle files 
    task :rhobundlemap => ["config:wp8"] do
      puts "rhobundlemap task started"

      chdir $srcdir
      file = File.open("RhoBundleMap.txt", "w+")
      stamp = 0

      Dir.glob(File.join("**", '*.*')).each do |f|
        if f.start_with?('db')          ||
           f.end_with?('.rb')           ||
           f.end_with?('.erb')          ||
           f == "apps/app_manifest.txt" ||
           f == "apps/rhoconfig.txt"    ||
           f == "apps/rhoconfig.txt.timestamp" ||
           f == "RhoBundleMap.txt"
          next;
        end

        if f.include?("app") ||
           f.include?("db")  ||
           f.include?("lib")
           dst_dir = File.join('rho', f) 
        else
           dst_dir = File.join('rho', f) 
        end

        file.puts dst_dir + "|" + dst_dir + "|"+ File.mtime(f).to_i.to_s
        puts f + "|" + File.mtime(f).to_i.to_s
      end

      file.close
    end

    # build native code
    task :rhodes => ["config:wp8"] do
      chdir $startdir

      out_dir = $startdir + "/"+ $config["build"]["wp8path"] +"/rhodes"
      cp $app_path + "/icon/icon.png", out_dir if File.exists? $app_path + "/icon/icon.ico"     

      chdir $config["build"]["wp8path"]

      doc = REXML::Document.new(File.open($startdir+"/"+$config["build"]["wp8path"]+"/rhodes/Properties/WMAppManifest.xml"))
      doc.elements.each("Deployment/App") { |element| 
        element.attributes["ProductID"] = "{"+$app_config["wp"]["productid"]+"}"
        element.attributes["Title"]     = $app_config["name"]
      }

      File.open($startdir + "/"+$config["build"]["wp8path"] + "/rhodes/Properties/WMAppManifest.xml", "w") { |f| doc.write f; f.close }

      args = ['rhodes.sln', '/property:Configuration=Release', '/t:Rebuild']

      puts "\nThe following step may take several minutes or more to complete depending on your processor speed\n\n"
      Jake.run($msbuild, args)
      unless $? == 0 
        puts "Error building"
        exit 1
      end

      chdir $startdir
    end 

    def addbundletoxapCommon(cfgName)
      out_dir = File.join($startdir, $vcbindir, "rhodes/#{cfgName}")
			tmp_dir = File.join($srcdir, "tmp")
      rho_dir = File.join(tmp_dir, "rho")
      
      rm_rf tmp_dir
      mkdir tmp_dir
      mkdir File.join(tmp_dir, 'rho')
      mkdir File.join(tmp_dir, 'rho', 'apps')

      appsFiles = FileList.new 
      appsFiles.include(File.join($srcdir, "apps", "*.*"))

      cp_r File.join($srcdir, "public"), tmp_dir
      cp   File.join($srcdir, "RhoBundleMap.txt"), tmp_dir
      cp_r File.join($srcdir, "apps"), rho_dir
      #cp_r appsFiles, File.join(rho_dir, 'apps')
      cp_r File.join($srcdir, "lib"), rho_dir
      cp_r File.join($srcdir, "db"), rho_dir

      chdir $startdir
      args = []
      args << "a"
      args << "-tzip"
      args << File.join(out_dir, "rhodes.xap")
      args << tmp_dir + "/*"
      puts Jake.run($zippath, args)
    end

    task :addbundletoxapDebug do
      addbundletoxapCommon('Debug')
    end

    task :addbundletoxapRelease => "config:wp8" do
      addbundletoxapCommon('Release')
    end

    task :rhobundle_production => [:rhobundle, :rhobundlemap] do
    end

    task :devrhobundleRelease => [:rhobundle, :rhobundlemap] do
      puts 'devrhobundleRelease task started'
      addRhobundleFilesToCacheFileCommon('Release')
      Rake::Task["build:wp8:addbundletoxapRelease"].invoke
    end

    task :devrhobundleDebug => [:rhobundle, :rhobundlemap] do
      puts 'devrhobundleDebug task started'
      addRhobundleFilesToCacheFileCommon('Debug')
      Rake::Task["build:wp8:addbundletoxapDebug"].invoke
    end
  end
end

def get_app_log()
  args = []
  args << $app_config["wp"]["productid"]
  args << ""
  args << ""
  args << ""
  args << "RhoLog.txt"

  cc_run($wp7runner, args) or return false
  puts "RhoLog.txt stored to " + $app_path
  return true
end

def run_rho_log_server()
  system("START rake run:wp:rhologserver[#{$app_path}]")
end
 
namespace "device" do
  namespace "wp8" do

    desc "Build production for device or emulator"
    task :production => ["build:wp8:rhobundle_production", "build:wp8:rhodes", "build:wp8:addbundletoxapRelease"] do
      out_dir = $startdir + "/" + $vcbindir + "/rhodes/Release/"
      cp  out_dir + "rhodes.xap", out_dir + $appname + ".xap"

      mkdir_p $bindir if not File.exists? $bindir
      mkdir_p $targetdir if not File.exists? $targetdir
      mv out_dir + $appname + ".xap", $targetdir
    end

    task :production_noxap => ["build:wp8:rhobundle_production", "build:wp8:rhodes"] do
      out_dir = $startdir + "/" + $vcbindir + "/rhodes/Release/"
      cp  out_dir + "rhodes.xap", out_dir + $appname + ".xap"

      mkdir_p $bindir if not File.exists? $bindir
      mkdir_p $targetdir if not File.exists? $targetdir
      mv out_dir + $appname + ".xap", $targetdir
    end
  end
end

namespace "clean" do
  desc "Clean wp"
  task :wp8 => "clean:wp8:all"
  namespace "wp8" do
    task :rhodes => ["config:wp"] do
      rm_rf $vcbindir
      rm_rf $targetdir
    end
    task :all => "clean:wp:rhodes"
  end
end

namespace "run" do

  def getLogPath
    log_file_path =  File.join($app_path, $app_config["applog"].nil? ? "applog.txt" : $app_config["applog"] )
    return log_file_path
  end

  desc "Build, install .xap and run on WP8 emulator"
  task :wp8 => ["device:wp8:production_noxap"] do
    if $app_config["wp"] && $app_config["wp"]["productid"] != nil

      File.delete($app_path + "/started") if File.exists?($app_path + "/started")
      Jake.run_rho_log_server($app_path)
      puts "RhoLogServer is starting"

      while(1)
        if File.exists?($app_path + "/started")
          break
        end
      end

      Rake::Task["build:wp8:addbundletoxapRelease"].invoke

      out_dir = $startdir + "/" + $vcbindir + "/rhodes/Release/"
      cp  out_dir + "rhodes.xap", out_dir + $appname + ".xap"
      mv out_dir + $appname + ".xap", $targetdir

      args = []
      args << $app_config["wp"]["productid"]
      args << $app_config["name"]
      args << $app_path + "/icon/icon.png"
      args << $targetdir + "/" + $appname + ".xap"
      args << "emu"
      puts Jake.run($wp7runner, args)

      #while(1)
      #	sleep(1000)
      #end
      #$rhologfile.close
    else
      puts "productid must be set in build.yml"
      puts "productid's format is xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    end
  end     

  namespace "wp8" do

    task :get_log => "config:wp" do
      puts "log_file=" + getLogPath
    end

    desc "Run application on RhoSimulator"    
    task :rhosimulator => ["config:set_wp8_platform", "config:common"] do    
      $rhosim_config = "platform='wp'\r\n"
      Rake::Task["run:rhosimulator"].invoke            
    end

    task :rhosimulator_debug => ["config:set_wp8_platform", "config:common"] do    
      $rhosim_config = "platform='wp'\r\n"
      Rake::Task["run:rhosimulator_debug"].invoke            
    end

    task :spec do
      Rake::Task["run:wp8"].invoke
      Jake.before_run_spec
      start = Time.now
      log_file = getLogPath

      puts "waiting for log: " + log_file

      for i in 0..120
        if !File.exist?(log_file)
          sleep(1)
        else
          break
        end
      end

      if !File.exist?(log_file)
        puts "Can not read log file: " + log_file
        exit(1)
       end

       puts "start read log"

       io = File.new(log_file, "r")
       waiting_count = 0
       end_spec = false

       while !end_spec do
         line_count = 0

        io.each do |line|
          end_spec = !Jake.process_spec_output(line)
          break if end_spec
          line_count += 1
        end

        if line_count==0
          waiting_count += 1
        else
          waiting_count = 0
        end

        if waiting_count > 240
          puts "spec application hung (240 seconds timeout)"
          end_spec = true
        end

        sleep(1) unless end_spec
      end

      io.close

      Jake.process_spec_results(start)

      $stdout.flush
      chdir $startdir
    end

    task :phone_spec do
      Jake.run_spec_app('wp8','phone_spec')
      exit 1 if $total.to_i==0
      exit $failed.to_i
    end

    desc "Build, install .xap and run on WP8 device"
    task :device => ["device:wp8:production_noxap"] do

      if $app_config["wp"] && $app_config["wp"]["productid"] != nil
        #system("START " + $wp7logserver + " " + $app_path + "/rholog.txt")
        File.delete($app_path + "/started")  if File.exists?($app_path + "/started")
        Jake.run_rho_log_server($app_path)

        puts "RhoLogServer is starting"
        while(1)
          if File.exists?($app_path + "/started")
            break
          end
        end

        Rake::Task["device:wp8:addbundletoxapRelease"].invoke
        out_dir = $startdir + "/" + $vcbindir + "/rhodes/Release/"
        cp  out_dir + "rhodes.xap", out_dir + $appname + ".xap"
        mv out_dir + $appname + ".xap", $targetdir

        args = []
        args << $app_config["wp"]["productid"]
        args << $app_config["name"]
        args << $app_path + "/icon/icon.png"
        args << $targetdir + "/" + $appname + ".xap"
        args << "dev"
        puts Jake.run($wp7runner, args)

        #while(1)
        #sleep(1000)
        #end
        #$rhologfile.close
      else
        puts "productid must be set in build.yml"
        puts "productid's format is xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
      end
    end
  end
end