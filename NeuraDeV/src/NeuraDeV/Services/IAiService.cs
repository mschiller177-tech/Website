using System.Threading.Tasks;
using NeuraDeV.Models;

namespace NeuraDeV.Services;

public interface IAiService
{
    Task<ChatMessage> RespondAsync(string userInput);
}
