import XCTest
@testable import osmDownloads

final class URLClassifierTests: XCTestCase {

    // MARK: - Hugging Face

    func testHFRepoRoot() {
        let kind = URLClassifier.classify("https://huggingface.co/meta-llama/Llama-3.1-8B-Instruct")
        guard case .huggingFace(let type, let org, let repo, let branch, let subpath, _) = kind else {
            return XCTFail("Expected .huggingFace, got \(kind)")
        }
        XCTAssertEqual(type, .models)
        XCTAssertEqual(org, "meta-llama")
        XCTAssertEqual(repo, "Llama-3.1-8B-Instruct")
        XCTAssertEqual(branch, "main")
        XCTAssertTrue(subpath.isEmpty)
    }

    func testHFTreeBranch() {
        let kind = URLClassifier.classify("https://huggingface.co/openai/whisper-large/tree/refs/pr/1/path/inside")
        guard case .huggingFace(_, _, _, let branch, let subpath, _) = kind else {
            return XCTFail("Expected .huggingFace, got \(kind)")
        }
        XCTAssertEqual(branch, "refs")
        XCTAssertEqual(subpath, "pr/1/path/inside")
    }

    func testHFDataset() {
        let kind = URLClassifier.classify("https://huggingface.co/datasets/squad/squad")
        guard case .huggingFace(let type, let org, let repo, _, _, _) = kind else {
            return XCTFail("Expected .huggingFace, got \(kind)")
        }
        XCTAssertEqual(type, .datasets)
        XCTAssertEqual(org, "squad")
        XCTAssertEqual(repo, "squad")
    }

    func testHFBlobIsFile() {
        let kind = URLClassifier.classify("https://huggingface.co/openai/whisper/blob/main/config.json")
        guard case .huggingFaceFile(_, _, _, let branch, let path, _) = kind else {
            return XCTFail("Expected .huggingFaceFile, got \(kind)")
        }
        XCTAssertEqual(branch, "main")
        XCTAssertEqual(path, "config.json")
    }

    func testHFResolveIsFile() {
        let kind = URLClassifier.classify("https://huggingface.co/openai/whisper/resolve/main/model.safetensors")
        guard case .huggingFaceFile(_, _, _, _, let path, _) = kind else {
            return XCTFail("Expected .huggingFaceFile, got \(kind)")
        }
        XCTAssertEqual(path, "model.safetensors")
    }

    // MARK: - GitHub

    func testGitHubRepoRoot() {
        let kind = URLClassifier.classify("https://github.com/apple/swift")
        guard case .github(let org, let repo, let branch, let subpath, _) = kind else {
            return XCTFail("Expected .github, got \(kind)")
        }
        XCTAssertEqual(org, "apple")
        XCTAssertEqual(repo, "swift")
        XCTAssertTrue(branch.isEmpty)
        XCTAssertTrue(subpath.isEmpty)
    }

    func testGitHubTreePath() {
        let kind = URLClassifier.classify("https://github.com/apple/swift/tree/main/stdlib/public")
        guard case .github(_, _, let branch, let subpath, _) = kind else {
            return XCTFail("Expected .github, got \(kind)")
        }
        XCTAssertEqual(branch, "main")
        XCTAssertEqual(subpath, "stdlib/public")
    }

    func testGitHubBlobIsFile() {
        let kind = URLClassifier.classify("https://github.com/apple/swift/blob/main/README.md")
        guard case .githubFile(_, _, _, let path, _) = kind else {
            return XCTFail("Expected .githubFile, got \(kind)")
        }
        XCTAssertEqual(path, "README.md")
    }

    func testGitHubReleasesIsGeneric() {
        let kind = URLClassifier.classify("https://github.com/apple/swift/releases/download/v1.0/asset.zip")
        guard case .generic(let url) = kind else {
            return XCTFail("Expected .generic, got \(kind)")
        }
        XCTAssertEqual(url.path, "/apple/swift/releases/download/v1.0/asset.zip")
    }

    // MARK: - Generic / invalid

    func testGenericURL() {
        let kind = URLClassifier.classify("https://example.com/foo.bin")
        guard case .generic(let url) = kind else {
            return XCTFail("Expected .generic, got \(kind)")
        }
        XCTAssertEqual(url.absoluteString, "https://example.com/foo.bin")
    }

    func testQueryStringPreservedForGeneric() {
        let kind = URLClassifier.classify("https://example.com/foo.bin?token=abc")
        guard case .generic(let url) = kind else {
            return XCTFail("Expected .generic, got \(kind)")
        }
        XCTAssertEqual(url.query, "token=abc")
    }

    func testEmptyIsInvalid() {
        if case .invalid = URLClassifier.classify("") { } else {
            XCTFail("Expected .invalid for empty input")
        }
    }

    func testWhitespaceIsInvalid() {
        if case .invalid = URLClassifier.classify("   \n  ") { } else {
            XCTFail("Expected .invalid for whitespace-only input")
        }
    }

    func testFTPSchemeIsInvalid() {
        if case .invalid = URLClassifier.classify("ftp://example.com/foo") { } else {
            XCTFail("Expected .invalid for ftp scheme")
        }
    }

    func testGarbageIsInvalid() {
        if case .invalid = URLClassifier.classify("not a url at all") { } else {
            XCTFail("Expected .invalid for garbage input")
        }
    }

    func testTrimsLeadingTrailingWhitespace() {
        let kind = URLClassifier.classify("   https://github.com/apple/swift   ")
        if case .github = kind { } else {
            XCTFail("Whitespace should be trimmed before classification: \(kind)")
        }
    }
}
