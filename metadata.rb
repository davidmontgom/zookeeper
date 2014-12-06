name             "zookeeper"
maintainer       "Rtb"
maintainer_email "nobdy"
license          "Apache 2.0"
description      "Installs zookeeper"
version          "1.0.0"
%w{ubuntu}.each do |os|
  supports os
end
