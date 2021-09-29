# 💊 pod-patch [![npm version](https://badge.fury.io/js/pod-patch.svg)](https://badge.fury.io/js/pod-patch)

Patching the Pods `podspec` files in **React Native** projects with the version tracking and `Podfile` updates.

# Why

When developing something using Cocoapods packages in some cases you need to modify the Pod's `podspec` file. Often these cases are:

- Change the Pod dependency,
- Modify compilation flags, paths, parameters,
- Using the Pod with connected sources or libraries from another Pod.

You can do it by hand, download `podspec` file, modify, it and point to the local `podspec` file at the main **Podfile**. But what if I say:

- That you need to patch a few Pods?
- Their versions are changing too?
- What if there are a bunch of the patched Pods with the different versions?

How not forget what and where was patched and patch them on the new versions or Podfile changes?

**🎈 This small tool was created to solve this!**

# Configuration

### This tool is created for use in the **React Native** project.

As this tool doesn't require many parameters we are using the **convention over configuration** approach.

By default tool will look into the `native/ios/patches` directory for the `.patch` files. The file name itself tells the tool which Pod and which version you want to patch the Pod's `podspec` and use it in your main Podfile.

The naming convention for the `.patch` files is `podName@version.patch` where `podName` is the name of the Pod and `version` is the Pod version to use for the patch apply.

For example, `native/ios/patches/gRPC-Core@1.40.0.patch` will tell that we want to apply patch from this file to the `gRPC-Core` podspec file for the `1.40.0` version.

Also, you can use it without a version. When using `native/ios/patches/gRPC-Core.patch` tool will apply the patch from this file to the `gRPC-Core` pod with the version from your Podfile. When using without a version you need to have a record in the Podfile with the pod and version.

For example:

```ruby
target 'App' do
    ...
    pod 'gRPC-Core', '1.40.0'
```

You can have as many `.patch` files as you need, the tool will use all of them.

# Running

The tool can be executed as the `npx pod-patch` command in the `native` directory of your **React Native** project.

When running the tool will iterate through your `.patch` files checks if anything has changed and made some magic:

- Checks if there is no version conflicts in your `Podfile` and `.patch` file,
- Download a `podspec` file for your Pod from the [cocoapods git repo](https://github.com/CocoaPods/Specs/tree/master/Specs) to the `native/ios/patches/{pod-name}/{pod-version}/` directory,
- Apply the patch from the `.patch` file to it,
- Changes the record for the patched **Pod** in the `Podfile` to point it to the local patched podspec. For example, the record for the `gRPC-Core` will automatically change to:

```ruby
target 'App' do
    ...
    pod 'gRPC-Core', :podspec => './patches/gRPC-Core/1.40.0/gRPC-Core.podspec.json'
```

The tool checks if the Pod is already patched.
If nothing changed from the already applied patches - it will do nothing.

## Using with the `yarn` or `npm i`

A good practice is to use is linked with the running of `yarn` or `npm i` in the `native` directory.

This will updates/install the packages with the transparent checking if all of the Pod patches are up-to-date or need to be applied if something in the `.patch` file changed or `Podspec` has new changes in the pod dependency or version changes.

# Pod version changing

In case when the Pod version changed but you already have a `.patch` file for the previous version and it is already applied, but you want to upgrade the Pod and patch to the new version there are three simple steps:

**First**, if your `.patch` file in the `native/ios/patches` has a version format i.e. `gRPC-Core@1.40.0.patch` you need to create a patch file for the new version i.e. `gRPC-Core@1.41.0.patch`.

If the `.patch` file in the no-version format i.e. `gRPC-Core.patch` you do nothing here as this is an universal patch for all versions.

**Second**, you need to point to the new version of the Pod in your `Podfile`. For example, upgrading to 1.41.0, need to look like:

```ruby
target 'App' do
    ...
    pod 'gRPC-Core', '1.41.0'
```

**Third**, you need to run `npx pod-patch` from your `native` directory and the tool will create a new patched Pod and point Podfile to it 🙌.

If you have a version-agnostic `.patch` file, actually you only need to do a second step only (point to the new version at the Podfile) and just run the tool!

# Command line flags

- `-h`: Output the command usage help.
- `-v`: Output the script version.
- `-p`: Path to the directory where the `.patch` files are if it differs from the default `native/ios/patches`.
- `-d`: Path to the `Podfile` if it differs from the default `native/ios/Podfile`.

# Todo

- [ ] Resolving conflicts if there are a few patch files for one Pod present.
