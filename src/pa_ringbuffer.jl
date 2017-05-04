"The pa_ringbuffer shared library"
const libpa_ringbuffer = Base.Libdl.find_library(
        ["pa_ringbuffer",],
        [joinpath(dirname(@__FILE__), "..", "deps", "usr", "lib"),])

@static if is_apple()
    const RingBufferSize = Int32
else
    const RingBufferSize = Clong
end

mutable struct PaUtilRingBuffer
    bufferSize::RingBufferSize # Number of elements in FIFO. Power of 2. Set by PaUtil_InitializeRingBuffer.
    writeIndex::RingBufferSize # Index of next writable element. Set by PaUtil_AdvanceRingBufferWriteIndex.
    readIndex::RingBufferSize # Index of next readable element. Set by PaUtil_AdvanceRingBufferReadIndex.
    bigMask::RingBufferSize # Used for wrapping indices with extra bit to distinguish full/empty.
    smallMask::RingBufferSize # Used for fitting indices to buffer.
    elementSizeBytes::RingBufferSize # Number of bytes per element.
    buffer::Ptr{Cchar} # Pointer to the buffer containing the actual data.

    # allow it to be created uninitialized because we need to pass it to PaUtil_InitializeRingBuffer
    function PaUtilRingBuffer(elementSizeBytes, elementCount)
        data = Base.Libc.malloc(elementSizeBytes * elementCount)
        rbuf = new()
        PaUtil_InitializeRingBuffer(rbuf, elementSizeBytes, elementCount, data)

        finalizer(rbuf, close)
        rbuf
    end
end

Base.close(rbuf::PaUtilRingBuffer) = Base.Libc.free(rbuf.buffer)

"""
    PaUtil_InitializeRingBuffer(rbuf, elementSizeBytes, elementCount, dataPtr)

Initialize Ring Buffer to empty state ready to have elements written to it.

# Arguments
* `rbuf::PaUtilRingBuffer`: The ring buffer.
* `elementSizeBytes::RingBufferSize`: The size of a single data element in bytes.
* `elementCount::RingBufferSize`: The number of elements in the buffer (must be a power of 2).
* `dataPtr::Ptr{Void}`: A pointer to a previously allocated area where the data
  will be maintained.  It must be elementCount*elementSizeBytes long.
"""
function PaUtil_InitializeRingBuffer(rbuf, elementSizeBytes, elementCount, dataPtr)
    if !ispow2(elementCount)
        throw(ErrorException("elementCount($elementCount) must be a power of 2"))
    end

    status = ccall((:PaUtil_InitializeRingBuffer, libpa_ringbuffer),
                   RingBufferSize,
                   (Ref{PaUtilRingBuffer}, RingBufferSize, RingBufferSize, Ptr{Void}),
                   rbuf, elementSizeBytes, elementCount, dataPtr)
    if status != 0
        throw(ErrorException("PaUtil_InitializeRingBuffer returned status $status"))
    end

    nothing
end


"""
    PaUtil_FlushRingBuffer(rbuf::PaUtilRingBuffer)

Reset buffer to empty. Should only be called when buffer is NOT being read or written.
"""
function PaUtil_FlushRingBuffer(rbuf)
    ccall((:PaUtil_FlushRingBuffer, libpa_ringbuffer),
          Void,
          (Ref{PaUtilRingBuffer}, ),
          rbuf)
end

"""
    PaUtil_GetRingBufferWriteAvailable(rbuf::PaUtilRingBuffer)

Retrieve the number of elements available in the ring buffer for writing.
"""
function PaUtil_GetRingBufferWriteAvailable(rbuf)
    ccall((:PaUtil_GetRingBufferWriteAvailable, libpa_ringbuffer),
          RingBufferSize,
          (Ref{PaUtilRingBuffer}, ),
          rbuf)
end

"""
    PaUtil_GetRingBufferReadAvailable(rbuf::PaUtilRingBuffer)

Retrieve the number of elements available in the ring buffer for reading.
"""
function PaUtil_GetRingBufferReadAvailable(rbuf)
    ccall((:PaUtil_GetRingBufferReadAvailable, libpa_ringbuffer),
          RingBufferSize,
          (Ref{PaUtilRingBuffer}, ),
          rbuf)
end

"""
    PaUtil_WriteRingBuffer(rbuf::PaUtilRingBuffer,
                           data::Ptr{Void},
                           elementCount::RingBufferSize)

Write data to the ring buffer and return the number of elements written.
"""
function PaUtil_WriteRingBuffer(rbuf, data, elementCount)
    ccall((:PaUtil_WriteRingBuffer, libpa_ringbuffer),
          RingBufferSize,
          (Ref{PaUtilRingBuffer}, Ptr{Void}, RingBufferSize),
          rbuf, data, elementCount)
end

"""
    PaUtil_ReadRingBuffer(rbuf::PaUtilRingBuffer,
                          data::Ptr{Void},
                          elementCount::RingBufferSize)

Read data from the ring buffer and return the number of elements read.
"""
function PaUtil_ReadRingBuffer(rbuf, data, elementCount)
    ccall((:PaUtil_ReadRingBuffer, libpa_ringbuffer),
          RingBufferSize,
          (Ref{PaUtilRingBuffer}, Ptr{Void}, RingBufferSize),
          rbuf, data, elementCount)
end
