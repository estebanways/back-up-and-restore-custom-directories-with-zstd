# back-up-and-restore-custom-directories-with-zstd

🛠️ Compresses specified directories ...

## Key Improvements

Faster Compression – zstd is significantly faster than gzip while maintaining good compression ratios.

Modern Format – Uses .tar.zst (or .tar.zstd) instead of .tgz.

Error Logging – Still logs errors to dirs.log.

Cleaner Script – Uses an array (dirs) for better readability.

## Optional Enhancements

Adjust Compression Level (default is 3, but you can set -3 to -19 or --fast):

```shell
sudo tar -cv --use-compress-program="zstd -9" -f "$backup_file" "${dirs[@]}"
```

Exclude Unnecessary Files (e.g., cache):

```shell
sudo tar -cv --exclude="*cache*" --use-compress-program=zstd -f "$backup_file" "${dirs[@]}"
```

Parallel Compression (if pigz or pzstd is available):

```shell
sudo tar -cv --use-compress-program="pzstd -9" -f "$backup_file" "${dirs[@]}"
```

To verify that your Zstandard-compressed archive (dirs_backup.tar.zst) is intact and not corrupted, you can use the following methods:

1. Test the Archive Without Extracting
Run this command to check the integrity of the .tar.zst file:

```shell
zstd -t dirs_backup.tar.zst
```

If it’s valid, you’ll see:

```plaintext
dirs_backup.tar.zst : 64.57%   (1443834880 => 932451543 bytes, dirs_backup.tar.zst)
```

If corrupted, you’ll get an error like:

```plaintext
dirs_backup.tar.zst : Decoding error (36) : Corrupted block detected
```

2. List Contents (Dry Run)
To check if files were archived correctly without extracting:

```shell
tar -tvf dirs_backup.tar.zst --use-compress-program=zstd
```

This lists all files in the archive.
If it fails, the archive might be damaged.

3. Compare Original Files vs. Archive (Optional)

For critical backups, compare file counts/hashes:

A. Count Files Before/After

```shell
# Count files in original directories
find "${dirs[@]}" -type f | wc -l

# Count files in the tarball
tar -tf dirs_backup.tar.zst --use-compress-program=zstd | wc -l

```

Similar counts suggest a good backup.

B. Verify Checksums (Advanced)

```shell
# Generate checksum of original files (takes time)
find "${dirs[@]}" -type f -exec sha256sum {} + > original_checksums.txt

# Extract the archive temporarily and verify
mkdir test_extract && cd test_extract
tar -xf ../dirs_backup.tar.zst --use-compress-program=zstd
find . -type f -exec sha256sum {} + > ../backup_checksums.txt
cd ..
diff original_checksums.txt backup_checksums.txt

```

No output = identical files.

Warning: This is slow for large backups.

## Extracting Guide

Here’s a step-by-step guide to extracting your Zstandard-compressed backup (dirs_backup.tar.zst) safely, with options for partial extraction, permission fixes, and error handling.

1. Basic Extraction (All Files)

```shell
# Create a directory to extract into (optional)
mkdir -p restored_backup

# Extract with preserved permissions (same paths as original)
sudo tar -xvf dirs_backup.tar.zst --use-compress-program=zstd -C restored_backup

```

-x: Extract

-C: Target directory (omit to extract in current dir)

-v: Verbose (show progress)

2. Verify After Extraction

```shell
# Check if critical dirs were extracted (e.g., /etc/)
ls -l restored_backup/etc/

# Test a file (e.g., nvim config)
cat restored_backup"$HOME"/.local/share/nvim/site/init.vim

```

3. Partial Extraction (Single File/Dir)

```shell
# List contents first (find the exact path)
tar -tf dirs_backup.tar.zst --use-compress-program=zstd | grep "BraveSoftware"

# Extract just Brave's config
sudo tar -xvf dirs_backup.tar.zst --use-compress-program=zstd -C ~/ \
    "$HOME/.config/BraveSoftware/"

```

4. Handle Permissions (If Broken)

If extracted files have wrong permissions:

```shell
# Reset ownership (run from inside `restored_backup`)
sudo chown -R $USER:$USER "$HOME"  # User files
sudo chown -R root:root etc/       # System files
```

5. Error Recovery (If Extraction Fails)

A. Corrupted Archive?

Re-check integrity:

```shell
zstd -t dirs_backup.tar.zst
```

If corrupt, try recovering partial data:

```shell
zstd -d --rm dirs_backup.tar.zst -o recovered.tar  # Decompress to .tar
tar -xvf recovered.tar -C restored_backup         # Try extracting
```

B. Missing Dependencies?

Ensure zstd is installed:

```shell
sudo apt install zstd    # Debian/Ubuntu
sudo pacman -S zstd      # Arch
brew install zstd        # macOS
```

### Key Notes

Use sudo for system dirs (e.g., /etc/).

--use-compress-program=zstd must match the compression used during backup.

For speed, add -T0 to use all CPU cores (e.g., zstd -T0).

## Improving Backup and Extraction with Dictionaries in Zstd

You can significantly improve both compression ratios and speed by using Zstandard's dictionary compression feature. Here's how to implement it in your backup system:

### Dictionary Compression Benefits

1. Better Compression: Especially effective when backing up similar data structures repeatedly

2. Faster Compression: Dictionary allows the algorithm to work more efficiently

3. Consistent Performance: Particularly beneficial for incremental backups

### Implementation Guide

1. Create a Dictionary

First, train a dictionary on sample data that represents what you'll be backing up:

```shell
# Collect sample files (adjust paths as needed)
find "${dirs[@]}" -type f -size -1M -exec cat {} + > samples.dat

# Train dictionary (adjust size as needed, 100KB is often good)
zstd --train -r "${dirs[@]}" -o mydict.zstdict --maxdict=100000

```

2. Modify Backup Command to Use Dictionary

```shell
sudo tar -cv --use-compress-program="zstd -9 --dict=mydict.zstdict" -f "$backup_file" "${dirs[@]}"
```

3. For Parallel Compression with Dictionary

```shell
sudo tar -cv --use-compress-program="pzstd -9 --dict=mydict.zstdict -T0" -f "$backup_file" "${dirs[@]}"
```

4. Dictionary Management Best Practices

  - Store the dictionary with your backups: The same dictionary must be used for compression and decompression

  - Update periodically: Refresh your dictionary every few months or when your data patterns change significanty

  - Version your dictionaries: Include creation date in filename (e.g., mydict-20230715.zstdict)

5. Extracting with Dictionary

```shell
# Basic extraction
sudo tar -xvf dirs_backup.tar.zst --use-compress-program="zstd --dict=mydict.zstdict" -C restored_backup

# For parallel decompression
sudo tar -xvf dirs_backup.tar.zst --use-compress-program="pzstd --dict=mydict.zstdict -T0" -C restored_backup

```

### Advanced Dictionary Techniques

1. Multiple Dictionaries: Create specialized dictionaries for different data types

```shell
# Config files dictionary
find /etc/ -type f -exec cat {} + | zstd --train -o etc-dict.zstdict

# User data dictionary
find "$HOME" -type f -exec cat {} + | zstd --train -o home-dict.zstdict

```

2. Dictionary Chain Loading: For mixed content

```shell
zstd -9 --dict=etc-dict.zstdict --dict=home-dict.zstdict
```

3. Automated Dictionary Selection: Script to choose dictionary based on content

```shell
# In your backup command:
dict_to_use=$(select_appropriate_dict.sh "${dirs[@]}")
sudo tar -cv --use-compress-program="zstd -9 --dict=$dict_to_use" -f "$backup_file" "${dirs[@]}"

```

### Verification with Dictionaries

When verifying your backups, include the dictionary:

```shell
# Test archive integrity
zstd -t --dict=mydict.zstdict dirs_backup.tar.zst

# List contents
tar -tvf dirs_backup.tar.zst --use-compress-program="zstd --dict=mydict.zstdict"

```

### Performance Considerations

Performance Considerations

- Dictionary size: Typically 100KB-1MB is sufficient
- Training data: Should be representative but doesn't need to be exhaustive
- Memory usage: Larger dictionaries require more RAM during compression/decompression

By implementing dictionary compression, you can expect:

- 10-30% better compression ratios for similar data
- 5-15% faster compression times
- More consistent performance across backups
