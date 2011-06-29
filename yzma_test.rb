report :my_report do

  opts = {
    :count => 10,
    :timeout => 1
  }

  compare "syndication.yellowpages.com/_priv/sysinfo",
          "beta-syndication.yellowpages.com/_priv/sysinfo", opts do
    randomize_param :param1, 1..23, :allow_blank => true, :optional => true
    randomize_param :param2, ["val1", "val2"]
  end

  compare "syndication.yellowpages.com/_priv/sysinfo",
          "beta-syndication.yellowpages.com/_priv/sysinfo",
          opts.merge(:only_data => ["*/ruby"], :title => "Ruby version only") do
    randomize_param :param1, 1..23, :allow_blank => true, :optional => true
    randomize_param :param2, ["val1", "val2"]
  end
end

