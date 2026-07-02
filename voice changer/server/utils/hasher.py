from io import FileIO

BUF_SIZE = 1024 * 1024 * 4 # 4MB

def compute_hash(f: FileIO, hasher) -> str:
    # Buffer is per-call: a shared module-level buffer corrupts hashes when
    # two threads (e.g. model load + sample download) hash concurrently.
    view = memoryview(bytearray(BUF_SIZE))
    while bytes_read := f.readinto(view):
        hasher.update(view[:bytes_read])
    return hasher.hexdigest()
