# Developer Authorization Policy

**NativeGrind** clients are open-source, but the **NativeServer API** is closed. To protect the platform's security and performance, connecting to our infrastructure is a privilege that requires explicit authorization.

---

## 1. How to Get Access

We manage access based on what you are trying to do. Find your category below to apply:

### Type A: Users on Unsupported Devices

If you want to use the official (or an approved) app, but your device doesn't support App Attest, you need a personal **API Key** (Bring Your Own Key) to connect.

* **How to apply:** Join the official NativeGrind Discord and run the `/apply-api-key` command.

### Type B: Developers Testing an App

If you are building a custom client or fork and need to test it against the live server, you need a **Development API Key**.

* **How to apply:** Your client's source code must be public or visible to us for review. Join the Discord and run the `/apply-api-key` command. Keys are issued on a limited, case-by-case basis.

### Type C: Global App Approval

If your custom client is complete, secure, and you want it granted global production access (App Attest approval) so anyone can use it without a personal key.

* **How to apply:** Email the contact address in our `README.md`. Include your project name, scope, security architecture, and a link to your source code.
* **Review:** Expect a 7-14 day review period. If approved, you will be added to our public registry.

---

## 2. The Rules of Access

Whether you are using a personal API key or running a globally approved app, your access can be revoked at any time, with or without notice, if you:

* Violate the **NativeGrind Personal Use Licence**.
* Introduce security vulnerabilities or cause server instability.
* Attempt to bypass authentication, rate limits, App Attest, or any other security mechanism.
* Build a client that deviates heavily from NativeGrind's core design standards.

---

## 3. Registry of Authorized Clients

The following clients have Global Authorization for production. *(Note: Individuals or developers using private API keys are not listed here).*

| Client Name              | Authorization Status | Maintainer   |
| ------------------------ | -------------------- | ------------ |
| **NativeGrind Official** | Global (Production)  | Jay Brammeld |

> **Legal Note:** Nothing in the NativeGrind Personal Use Licence automatically grants you access to the NativeServer API. Any client not on this list—and not using a valid Development API Key—is unauthorized.