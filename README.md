# appssemble Communication Framework

iOS communication framework based on multipeer connectivity and WebRTC. It provides real time communication and time synchronization. It uses libjingle, WebRTC, SocketRocket, ntp and the MultiplayerConnectivity Framework. It provides 2 types of communication, via RTC and by using muliplayer connectivity in the local network.

## Getting Started

These instructions will help you get a copy of the project up and running on your local machine for development and testing purposes.

### Installing

In order to use the library you can direct download it, build it and use it in your projects, or you can use Cocoa Pods.

In order to install it via Pods, add the following to your pod file

```
pod 'appssembleCommunicationFramework'
```

Because of the fact that this framework uses the WebRTC library which is not bitcode compatible, you need to disable the bitcode for it in your pods project. This can be acomplished like in the example below:

```
post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            if target.name == "appssembleCommunicationFramework"
                config.build_settings['ENABLE_BITCODE'] = 'NO'
            end
        end
    end
end
```

This should be added at the end of the Podfile



Add additional notes about how to deploy this on a live system

## Built With

* [Dropwizard](http://www.dropwizard.io/1.0.2/docs/) - The web framework used
* [Maven](https://maven.apache.org/) - Dependency Management
* [ROME](https://rometools.github.io/rome/) - Used to generate RSS Feeds

## Contributing

Please read [CONTRIBUTING.md](https://gist.github.com/PurpleBooth/b24679402957c63ec426) for details on our code of conduct, and the process for submitting pull requests to us.

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [tags on this repository](https://github.com/your/project/tags). 

## Authors

* **Billie Thompson** - *Initial work* - [PurpleBooth](https://github.com/PurpleBooth)

See also the list of [contributors](https://github.com/your/project/contributors) who participated in this project.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments

* Hat tip to anyone who's code was used
* Inspiration
* etc
