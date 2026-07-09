# NativeGrind (Swift)

**NativeGrind** is an unofficial native Swift client for all Apple platforms. Built from the ground up using SwiftUI, it aims to provide a fast, clean, and secure native interface.

> [!IMPORTANT]
> While **NativeGrind** is open, Connecting to the API infastructure requires the following of [Developer Authorization Policy](./AUTHORIZATION.md)

## Architecture & Modules

This project is split into separate modules to split up the UI, resuable logic and NativeServer connections.

| Module                                       | Type          | Description                        | Key Responsibilities                                        |
| -------------------------------------------- | ------------- | ---------------------------------- | ----------------------------------------------------------- |
| **[NativeGrind](./NativeGrind)**             | Frontend      | The main SwiftUI application       | UI/UX for iOS, macOS, tvOS, visionOS and iPadOS.            |
| **[WatchNativeGrind](./WatchNativeGrind)**   | Frontend      | The main watch SwiftUI application | UI/UX for watchOS.                                          |
| **[NativeGrindCore](./NativeGrindCore)**     | Swift Package | Reusable application logic         | REST API client, Keychain secure storage, and strong types. |
| **[NativeGrindServer](./NativeGrindServer)** | Swift Package | NativeServer connector             | Interfaces with NativeServer to allow for extra features    |

## Getting Started

### Prerequisites

Development Requirements
* **Xcode 15+**
* **macOS 14+**

Minimum Target Versions
* **Main App:** iOS 17.0+, macOS 14.0+, tvOS 17.0+, and visionOS 2.0+
* **Watch App:** watchOS 10+

### Step 1: Clone the Repository

```bash
git clone https://github.com/imaoreo/NativeGrind-Swift.git
cd NativeGrind-Swift
```

### Step 2: Obtain a Developer Key

Due to how Apple App Attest and DeviceCheck is set up, unless you have been added to the [Authorized Client Registry](./AUTHORIZATION.md#3-registry-of-authorized-clients) you will have to apply for a developer key [How to Apply](./AUTHORIZATION.md#type-b-developers-testing-an-app) or you will not be able to access the NativeServer application.

### Step 3: Build and Run

Select your desired target (**NativeGrind** for iOS/macOS, or **WatchNativeGrind Watch App** for watchOS) and target device, then press **Cmd + R**.

## Security

To minimize potential security risks, we implement the following practices:
- **App Attest Enforcement:** NativeServer blocks unauthorized access by requiring proof of device integrity via Apple's App Attest API (or a registered developer key).
- **Dependency Minimization:** We rely on native Swift and Apple frameworks wherever possible to limit third-party vulnerabilities and bloat.
- **Transparent Reporting:** We maintain an open channel for anyone to report security issues, ensuring bugs can be patched quickly.

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change. Ensure that you update tests as appropriate.

You may also read [Contributing Guide](./CONTRIBUTING.md)

## Legal Disclaimer

Grindr is a registered trademark of Grindr LLC. This project is an independent, unofficial client and is not affiliated with, authorized, sponsored, or endorsed by Grindr LLC in any way. Use of this application may violate Grindr's Terms of Service. **Use at your own risk.**